function Initialize-DabMcpServer {
  <#
  .SYNOPSIS
  Installs DAB and initializes an MCP configuration.

  .DESCRIPTION
  Orchestrates the setup steps without embedding connection strings. Use Add-DabMcpEntity
  separately to explicitly choose which database objects the MCP server can expose.

  .OUTPUTS
  PSCustomObject.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [string] $Version = '2.0.9',

    [string] $ConfigPath = (Join-Path $env:APPDATA 'ATAP\DataApiBuilder\ATAPUtilities\dab-config.json'),

    [switch] $Force
  )

  begin {
    $fn = 'Initialize-DabMcpServer'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Initializing Data API Builder MCP server prerequisites.'
  }

  process {
    try {
      $install = Install-DabGlobalTool -Version $Version -WhatIf:$WhatIfPreference -Confirm:$false
      $config = Initialize-DabMcpConfiguration -ConfigPath $ConfigPath -Force:$Force -WhatIf:$WhatIfPreference -Confirm:$false
      [pscustomobject]@{ Installation = $install; Configuration = $config }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "DAB MCP server initialization failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed Data API Builder MCP server initialization.'
  }
}
