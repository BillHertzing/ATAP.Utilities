function Get-RepositoryRoot {
  <#
  .SYNOPSIS
  Finds and returns a Git repository root directory.
  .DESCRIPTION
  Uses `git rev-parse --show-toplevel` from StartPath. By default the result is
  relative to the caller's original location; -Absolute preserves Git's absolute
  worktree path for safe-directory and path-comparison callers.
  .PARAMETER StartPath
  Existing directory from which Git resolves the repository root.
  .PARAMETER Absolute
  Returns Git's absolute root instead of a caller-relative path.
  .OUTPUTS
  System.String
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter()]
    [string]$StartPath = (Get-Location).Path,

    [Parameter()]
    [switch]$Absolute
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.Common.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Searching for repository root starting from: $StartPath"
  }

  process {
    if (-not (Test-Path -LiteralPath $StartPath -PathType Container)) {
      $message = "Start path does not exist: $StartPath"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
      throw $message
    }

    $originalPath = (Get-Location).Path
    Push-Location
    try {
      Set-Location -LiteralPath $StartPath
      $gitResult = git rev-parse --show-toplevel 2>&1
      if ($LASTEXITCODE -ne 0) {
        $message = "git rev-parse --show-toplevel failed: $gitResult"
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
        throw $message
      }

      $absoluteRoot = ([string]$gitResult).Trim()
      if ($Absolute) {
        return $absoluteRoot
      }

      try {
        return (Resolve-Path -LiteralPath $absoluteRoot -Relative -RelativeBasePath $originalPath)
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Relative conversion failed; returning absolute root. $($_.Exception.Message)"
        return $absoluteRoot
      }
    } finally {
      Pop-Location
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving function'
  }
}
