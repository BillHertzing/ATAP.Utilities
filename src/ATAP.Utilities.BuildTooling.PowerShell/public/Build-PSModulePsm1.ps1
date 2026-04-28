<#
.SYNOPSIS
  Builds a consolidated PowerShell module (.psm1) file from the source files of a module.
.DESCRIPTION
  Enumerates *.ps1 files under each named sub-directory of $ModuleRoot (defaulting to
  'public', 'private', and 'lib'), parses each file with the PowerShell AST, then:
    1. Strips and deduplicates all #Requires directives, retaining only the highest
        -RunAsAdministrator is emitted at most once; hoists all to the very top.
    2. Collects and deduplicates all 'using namespace' and 'using assembly' statements,
      sorts them (namespace first, then assembly, then other), and hoists them below the
      Requires block.
    3. Concatenates the remaining file bodies, each preceded by a '# <filename>' header.
  An empty module (no .ps1 files found) produces an empty .psm1 and logs a warning
  instead of throwing. Missing parent directories of $OutputPath are created automatically.
  Supports -WhatIf to preview without writing.
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
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Entering function'

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: ModuleRoot)
    $ModuleRoot = Get-PVal -ParameterName ModuleRoot -originalPSBoundParameters $PSBoundParameters -dottedPath ModuleRoot -DefaultValue $ModuleRoot

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: OutputPath)
    $OutputPath = Get-PVal -ParameterName OutputPath -originalPSBoundParameters $PSBoundParameters -dottedPath OutputPath -DefaultValue $OutputPath

    # Check and populate simple parameter (snippet: CheckAndPopulateSimpleParameter, param: SourceDirectoryNames)
    $SourceDirectoryNames = Get-PVal -ParameterName SourceDirectoryNames -originalPSBoundParameters $PSBoundParameters -dottedPath SourceDirectoryNames -DefaultValue $SourceDirectoryNames

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "ModuleRoot='$ModuleRoot'  OutputPath='$OutputPath'"
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
        $found = Get-ChildItem -Path $subDirPath -Filter '*.ps1' -File -Recurse -ErrorAction SilentlyContinue |
          Sort-Object FullName
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

      # Collect unique #Requires directives and using statements; build per-file body stripped of both
      $requiresSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
      $usingSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
      $orderedUsings = [System.Collections.Generic.List[string]]::new()
      $fileBodies = [System.Collections.Generic.List[PSCustomObject]]::new()

      foreach ($srcFile in $sourceFiles) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Parsing AST for '$($srcFile.FullName)'"

        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($srcFile.FullName, [ref]$tokens, [ref]$parseErrors)

        $fileText = [System.IO.File]::ReadAllText($srcFile.FullName)
        $bodyText = $fileText

        # Strip AST-detected 'using' statements (working highest offset first to preserve positions)
        if ($ast.UsingStatements -and $ast.UsingStatements.Count -gt 0) {
          $sortedAstUsings = $ast.UsingStatements | Sort-Object -Property { $_.Extent.StartOffset } -Descending
          foreach ($u in $sortedAstUsings) {
            $usingLine = $u.Extent.Text.Trim()
            if ($usingSet.Add($usingLine)) {
              [void]$orderedUsings.Add($usingLine)
            }
            $bodyText = $bodyText.Remove($u.Extent.StartOffset, $u.Extent.EndOffset - $u.Extent.StartOffset)
          }
        }

        # Strip #Requires lines from the remaining body text
        $bodyLines = $bodyText -split "`r?`n"
        # also catches '# #Requires' (commented-out requires) and case variants
        $requiresLines = $bodyLines | Where-Object { $_ -match '^\s*#\s*[Rr]equires\s' }
        $bodyLines = $bodyLines | Where-Object { $_ -notmatch '^\s*#\s*[Rr]equires\s' }
        foreach ($req in $requiresLines) {
          $requiresSet.Add($req.Trim()) | Out-Null
        }

        $fileBodies.Add([PSCustomObject]@{
            Name = $srcFile.Name
            Body = ($bodyLines -join "`n")
          })
      }

      # Resolve #Requires -Version: keep only the highest; pass all other #Requires through unchanged
      $versionRequires = $requiresSet | Where-Object { $_ -match '#Requires\s+-Version\s+([\d.]+)' }
      $otherRequires = $requiresSet | Where-Object { $_ -notmatch '#Requires\s+-Version\s+' }

      $highestVersion = $versionRequires |
        ForEach-Object {
          if ($_ -match '#Requires\s+-Version\s+([\d.]+)') { [version] $Matches[1] }
        } |
        Sort-Object -Descending |
        Select-Object -First 1

      # Separate flag-style, -Modules, and -Assembly requires for proper dedup
      $runAsAdmin = $requiresSet | Where-Object { $_ -match '#Requires\s+-RunAsAdministrator' }
      $moduleReqs = $requiresSet | Where-Object { $_ -match '#Requires\s+-Modules\s' }
      $assemblyReqs = $requiresSet | Where-Object { $_ -match '#Requires\s+-Assembly\s' }
      $psEditionReqs = $requiresSet | Where-Object { $_ -match '#Requires\s+-PSEdition\s' }

      # Deduplicate -Modules by module name, keeping the highest version
      $dedupedModules = $moduleReqs | ForEach-Object {
        if ($_ -match '#Requires\s+-Modules\s+@\{ModuleName\s*=\s*[''"]?([^''";\s]+)[''"]?.*Version\s*=\s*[''"]?([\d.]+)') {
          [PSCustomObject]@{ Raw = $_; ModuleName = $Matches[1]; Version = [version]$Matches[2] }
        } elseif ($_ -match '#Requires\s+-Modules\s+([^\s]+)') {
          [PSCustomObject]@{ Raw = $_; ModuleName = $Matches[1]; Version = [version]'0.0' }
        }
      } | Where-Object { $_ } |
      Group-Object ModuleName |
      ForEach-Object {
        ($_.Group | Sort-Object Version -Descending | Select-Object -First 1).Raw
      }

      $finalRequires = [System.Collections.Generic.List[string]]::new()

      # Emit in conventional order: -Version, -PSEdition, -RunAsAdministrator, -Modules, -Assembly
      if ($highestVersion) {
        [void]$finalRequires.Add("#Requires -Version $highestVersion")
      }
      foreach ($req in $psEditionReqs) { [void]$finalRequires.Add($req) }
      if ($runAsAdmin) { [void]$finalRequires.Add('#Requires -RunAsAdministrator') }
      foreach ($req in $dedupedModules) { [void]$finalRequires.Add($req) }
      foreach ($req in $assemblyReqs) { [void]$finalRequires.Add($req) }

      # Re-order unique usings: namespace statements first, then assembly, then other
      $sortedUsings = @()
      $sortedUsings += $orderedUsings | Where-Object { $_ -match '^\s*using\s+namespace\s' }
      $sortedUsings += $orderedUsings | Where-Object { $_ -match '^\s*using\s+assembly\s' }
      $sortedUsings += $orderedUsings | Where-Object { $_ -notmatch '^\s*using\s+(namespace|assembly)\s' }

      # Assemble the final output
      $sb = [System.Text.StringBuilder]::new()

      foreach ($req in $finalRequires) {
        [void]$sb.AppendLine($req)
      }
      if ($finalRequires.Count -gt 0) {
        [void]$sb.AppendLine()
      }

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

      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Built: '$OutputPath' ($($sourceFiles.Count) source files, $($requiresSet.Count) #Requires collected, $($usingSet.Count) using statements hoisted)"

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
