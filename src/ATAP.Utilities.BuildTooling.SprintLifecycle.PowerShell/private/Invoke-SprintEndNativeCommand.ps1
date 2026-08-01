function Invoke-SprintEndNativeCommand {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,

    [Parameter()]
    [AllowEmptyCollection()]
    [string[]]$ArgumentList = @(),

    [Parameter()]
    [switch]$AllowNonZeroExitCode
  )

  begin {
    $fn = 'Invoke-SprintEndNativeCommand'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Calling native command '$FilePath'." -Tag 'InvokeCommandCall'
  }

  process {
    $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { [string]$_ })
    $exitCode = $LASTEXITCODE
    $result = [PSCustomObject]@{
      FilePath     = $FilePath
      ArgumentList = @($ArgumentList)
      ExitCode     = $exitCode
      Output       = @($output)
      Succeeded    = ($exitCode -eq 0)
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug `
      -Message "Native command '$FilePath' completed with exit code $exitCode." `
      -Tag 'InvokeCommandCall'

    if (-not $result.Succeeded -and -not $AllowNonZeroExitCode) {
      throw "Native command '$FilePath' failed with exit code $exitCode. $($output -join [Environment]::NewLine)"
    }

    return $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Function completed'
  }
}
