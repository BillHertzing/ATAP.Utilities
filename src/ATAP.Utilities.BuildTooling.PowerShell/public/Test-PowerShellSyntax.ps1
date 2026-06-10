function Test-PowerShellSyntax {
  <#
  .SYNOPSIS
    Parses a PowerShell script file and reports syntax errors.
  .DESCRIPTION
    Uses System.Management.Automation.Language.Parser to parse a target .ps1 file
    without executing it. Returns a result object instead of exiting the host.
  .PARAMETER Path
    Path to the PowerShell script file to parse.
  .OUTPUTS
    PSCustomObject with Path, Success, ErrorCount, and Errors properties.
  .EXAMPLE
    Test-PowerShellSyntax -Path .\public\Invoke-Flyway.ps1
  .NOTES
    AI assisted using Powershell.instructions.md as guidelines
  .LINK
    System.Management.Automation.Language.Parser
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [Alias('FullName')]
    [string]$Path
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
      throw "PowerShell script file not found: $Path"
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
      $resolvedPath,
      [ref]$tokens,
      [ref]$errors
    )

    if ($errors.Count -eq 0) {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important -Message "Syntax OK - no parse errors in $resolvedPath"
    } else {
      foreach ($parseError in $errors) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Syntax error in $resolvedPath`: $($parseError.ToString())"
      }
    }

    [PSCustomObject]@{
      Path       = $resolvedPath
      Success    = ($errors.Count -eq 0)
      ErrorCount = $errors.Count
      Errors     = $errors
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn in module $mn"
  }
}