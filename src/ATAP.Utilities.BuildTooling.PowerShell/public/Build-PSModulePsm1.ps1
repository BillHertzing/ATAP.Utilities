<#
.SYNOPSIS
  Builds a consolidated PowerShell module (.psm1) file from the source files of a module.
.DESCRIPTION
  Enumerates *.ps1 files under each named sub-directory of $ModuleRoot (defaulting to
  'public', 'private', and 'lib'), parses each file into an AST, collects all 'using
  namespace' and 'using assembly' statements, de-duplicates them, and writes a single
  .psm1 file to $OutputPath with the `using` statements hoisted to the very top. Each
  source file is emitted below the hoisted `using` block with a `# <filename>.ps1`
  header comment. An empty module (no .ps1 files found) produces an empty .psm1 and
  logs a warning instead of throwing.
.PARAMETER ModuleRoot
  The absolute path to the root of the module whose source directories will be
  concatenated into a single .psm1 file.
.PARAMETER OutputPath
  The absolute path of the generated .psm1 file. Any missing parent directories are
  created automatically.
.PARAMETER SourceDirectoryNames
  The names of the sub-directories of $ModuleRoot whose *.ps1 files should be
  included. Defaults to @('public','private','lib').
.OUTPUTS
  System.IO.FileInfo
  A FileInfo handle to the generated .psm1 file.
.EXAMPLE
  Build-PSModulePsm1 -ModuleRoot 'C:/src/MyModule' -OutputPath 'C:/out/MyModule.psm1'
.EXAMPLE
  Build-PSModulePsm1 -ModuleRoot 'C:/src/MyModule' -OutputPath 'C:/out/MyModule.psm1' -SourceDirectoryNames @('public','private')
.NOTES
  AI assisted using Powershell.instructions.md as guidelines
.LINK
  https://github.com/whertzing/ATAP.Utilities
#>
function Build-PSModulePsm1 {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([System.IO.FileInfo])]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ModuleRoot,

    [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputPath,

    [Parameter(Mandatory = $false, Position = 2, ValueFromPipelineByPropertyName = $true)]
    [string[]] $SourceDirectoryNames = @('public', 'private', 'lib')
  )

  begin {
    $fn = 'Build-PSModulePsm1'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'
  }

  process {
    if (-not $PSCmdlet.ShouldProcess($OutputPath, "Write generated .psm1 for ModuleRoot '$ModuleRoot'")) {
      return
    }

    try {
      # Enumerate source .ps1 files across requested sub-directories
      $sourceFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
      foreach ($subDirName in $SourceDirectoryNames) {
        $subDirPath = Join-Path -Path $ModuleRoot -ChildPath $subDirName
        if (-not (Test-Path -Path $subDirPath -PathType Container)) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Sub-directory '$subDirPath' does not exist; skipping"
          continue
        }
        $found = Get-ChildItem -Path $subDirPath -Filter '*.ps1' -File -Recurse -ErrorAction SilentlyContinue
        foreach ($f in $found) {
          [void]$sourceFiles.Add($f)
        }
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Found $($sourceFiles.Count) source .ps1 file(s) under '$ModuleRoot'"

      # Ensure parent directory of $OutputPath exists
      $outputParent = Split-Path -Path $OutputPath -Parent
      if ($outputParent -and -not (Test-Path -Path $outputParent -PathType Container)) {
        New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
      }

      # Empty module guard
      if ($sourceFiles.Count -eq 0) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Tag 'Warning' -Message "No .ps1 files found under '$ModuleRoot'; writing empty .psm1 to '$OutputPath'"
        Set-Content -Path $OutputPath -Value '' -Encoding utf8BOM
        return (Get-Item -LiteralPath $OutputPath)
      }

      # Collect unique using statements across files and build per-file body stripped of using statements
      $usingStatementSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
      $orderedUsings = [System.Collections.Generic.List[string]]::new()
      $fileBodies = [System.Collections.Generic.List[PSCustomObject]]::new()

      foreach ($srcFile in $sourceFiles) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Parsing AST for '$($srcFile.FullName)'"

        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($srcFile.FullName, [ref]$tokens, [ref]$parseErrors)

        $fileText = [System.IO.File]::ReadAllText($srcFile.FullName)
        $bodyText = $fileText

        if ($ast.UsingStatements -and $ast.UsingStatements.Count -gt 0) {
          # Sort by StartOffset descending so we can safely Remove by index without shifting earlier offsets
          $sortedUsings = $ast.UsingStatements | Sort-Object -Property { $_.Extent.StartOffset } -Descending
          foreach ($u in $sortedUsings) {
            $usingLine = $u.Extent.Text.Trim()
            if ($usingStatementSet.Add($usingLine)) {
              [void]$orderedUsings.Add($usingLine)
            }
            $startOffset = $u.Extent.StartOffset
            $endOffset = $u.Extent.EndOffset
            # Remove the using statement's span from the body text
            $bodyText = $bodyText.Remove($startOffset, $endOffset - $startOffset)
          }
        }

        $fileBodies.Add([PSCustomObject]@{
            Name = $srcFile.Name
            Body = $bodyText
          })
      }

      # Re-order the unique usings: namespace statements first, then assembly, then module, preserving discovery order within each group
      $sortedUsings = @()
      $sortedUsings += $orderedUsings | Where-Object { $_ -match '^\s*using\s+namespace\s' }
      $sortedUsings += $orderedUsings | Where-Object { $_ -match '^\s*using\s+assembly\s' }
      $sortedUsings += $orderedUsings | Where-Object { $_ -notmatch '^\s*using\s+(namespace|assembly)\s' }

      $sb = [System.Text.StringBuilder]::new()

      foreach ($u in $sortedUsings) {
        [void]$sb.AppendLine($u)
      }
      if ($sortedUsings.Count -gt 0) {
        [void]$sb.AppendLine()
      }

      foreach ($entry in $fileBodies) {
        [void]$sb.AppendLine("# $($entry.Name)")
        [void]$sb.AppendLine($entry.Body.TrimStart("`r", "`n"))
      }

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Writing generated .psm1 to '$OutputPath'"
      Set-Content -Path $OutputPath -Value $sb.ToString() -Encoding utf8BOM

      return (Get-Item -LiteralPath $OutputPath)
    } catch {
      $errorMessage = "Failed to build .psm1 for ModuleRoot '$ModuleRoot'. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving PROCESS block'
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
  }
}
