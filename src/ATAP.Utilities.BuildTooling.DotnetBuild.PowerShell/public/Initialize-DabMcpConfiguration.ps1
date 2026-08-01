function Initialize-DabMcpConfiguration {
  <#
  .SYNOPSIS
  Creates a secret-free Data API Builder configuration for an MCP server.

  .DESCRIPTION
  Uses DAB's @env() configuration syntax, leaving the connection string outside the
  JSON file. Existing configuration is preserved unless Force is specified.

  .PARAMETER ConfigPath
  DAB configuration file to create.

  .PARAMETER ConnectionStringEnvironmentVariable
  Process environment variable that DAB resolves at startup.

  .OUTPUTS
  PSCustomObject.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [string] $ConfigPath = (Join-Path $env:APPDATA 'ATAP\DataApiBuilder\ATAPUtilities\dab-config.json'),

    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*$')]
    [string] $ConnectionStringEnvironmentVariable = 'DAB_ATAPUTILITIES_CONNECTION_STRING',

    [switch] $Force
  )

  begin {
    $fn = 'Initialize-DabMcpConfiguration'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Preparing DAB MCP configuration '$ConfigPath'."
  }

  process {
    try {
      if ((Test-Path -LiteralPath $ConfigPath -PathType Leaf) -and -not $Force) {
        return [pscustomobject]@{ ConfigPath = $ConfigPath; Action = 'Preserved'; WhatIf = $false }
      }

      $configDirectory = Split-Path -Path $ConfigPath -Parent
      if (-not $PSCmdlet.ShouldProcess($ConfigPath, 'Create secret-free DAB MCP configuration')) {
        return [pscustomobject]@{ ConfigPath = $ConfigPath; Action = 'Create'; WhatIf = $true }
      }

      $dab = Get-Command -Name 'dab' -ErrorAction Stop
      New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
      if ($Force -and (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        Remove-Item -LiteralPath $ConfigPath -Force
      }
      $connectionStringReference = "@env('$ConnectionStringEnvironmentVariable')"
      $result = Invoke-DabCommand -DabPath $dab.Source -ArgumentList @(
        'init', '--database-type', 'mssql', '--host-mode', 'Development',
        '--connection-string', $connectionStringReference, '--config', $ConfigPath
      )
      [pscustomobject]@{ ConfigPath = $ConfigPath; Action = 'Created'; WhatIf = $false; ExitCode = $result.ExitCode }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "DAB MCP configuration initialization failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed DAB MCP configuration initialization.'
  }
}
