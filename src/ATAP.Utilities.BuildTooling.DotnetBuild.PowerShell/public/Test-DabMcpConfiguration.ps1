function Test-DabMcpConfiguration {
  <#
  .SYNOPSIS
  Validates a Data API Builder MCP configuration.

  .DESCRIPTION
  Runs `dab validate` without starting an HTTP or MCP listener.

  .OUTPUTS
  PSCustomObject.
  #>
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param(
    [string] $ConfigPath = (Join-Path $env:APPDATA 'ATAP\DataApiBuilder\ATAPUtilities\dab-config.json')
  )

  begin {
    $fn = 'Test-DabMcpConfiguration'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Validating DAB MCP configuration '$ConfigPath'."
  }

  process {
    try {
      if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "DAB config '$ConfigPath' does not exist."
      }
      $dab = Get-Command -Name 'dab' -ErrorAction Stop
      $result = Invoke-DabCommand -DabPath $dab.Source -ArgumentList @('validate', '--config', $ConfigPath)
      [pscustomobject]@{ ConfigPath = $ConfigPath; Valid = $result.ExitCode -eq 0; ExitCode = $result.ExitCode }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "DAB MCP configuration validation failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed DAB MCP configuration validation.'
  }
}
