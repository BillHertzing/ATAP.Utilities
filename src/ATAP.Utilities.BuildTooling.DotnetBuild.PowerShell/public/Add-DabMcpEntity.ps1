function Add-DabMcpEntity {
  <#
  .SYNOPSIS
  Adds a read-only entity to a Data API Builder MCP configuration.

  .DESCRIPTION
  Adds an entity with an explicit least-privilege permission role. It does not grant
  anonymous write operations.

  .OUTPUTS
  PSCustomObject.
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $EntityName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $EntitySource,

    [string] $ConfigPath = (Join-Path $env:APPDATA 'ATAP\DataApiBuilder\ATAPUtilities\dab-config.json'),

    [ValidateNotNullOrEmpty()]
    [string] $Role = 'mcp-reader'
  )

  begin {
    $fn = 'Add-DabMcpEntity'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message "Preparing DAB entity '$EntityName'."
  }

  process {
    try {
      if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "DAB config '$ConfigPath' does not exist. Run Initialize-DabMcpConfiguration first."
      }
      $dab = Get-Command -Name 'dab' -ErrorAction Stop
      $arguments = @('add', $EntityName, '--config', $ConfigPath, '--source', $EntitySource, '--permissions', "$Role`:read")
      if (-not $PSCmdlet.ShouldProcess($ConfigPath, "Add DAB MCP entity '$EntityName'")) {
        return [pscustomobject]@{ EntityName = $EntityName; ConfigPath = $ConfigPath; WhatIf = $true; ExitCode = 0 }
      }
      $result = Invoke-DabCommand -DabPath $dab.Source -ArgumentList $arguments
      [pscustomobject]@{ EntityName = $EntityName; ConfigPath = $ConfigPath; WhatIf = $false; ExitCode = $result.ExitCode }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Adding DAB MCP entity failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed DAB MCP entity update.'
  }
}
