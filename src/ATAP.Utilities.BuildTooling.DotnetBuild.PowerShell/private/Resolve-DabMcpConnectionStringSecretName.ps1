function Resolve-DabMcpConnectionStringSecretName {
  <#
  .SYNOPSIS
  Resolves the canonical BWS secret name for a DAB MCP data source.

  .OUTPUTS
  String.
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Production', 'QA', 'Integration', 'Dev', 'Exp')]
    [string] $Tier,

    [ValidateNotNullOrEmpty()]
    [string] $DatabaseHost = $env:COMPUTERNAME,

    [ValidateNotNullOrEmpty()]
    [string] $DatabaseName = 'ATAPUtilities',

    [string] $UserName = $env:USERNAME
  )

  begin {
    $fn = 'Resolve-DabMcpConnectionStringSecretName'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Resolving DAB MCP secret name for tier '$Tier'."
  }

  process {
    try {
      if (-not (Get-Command -Name 'Get-DbConnectionStringSecretDescriptor' -ErrorAction SilentlyContinue)) {
        Import-Module -Name 'ATAP.Utilities.BuildTooling.Secrets.PowerShell' -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction Stop
      }
      $parameters = @{ DatabaseName = $DatabaseName; DatabaseHost = $DatabaseHost; Environment = $Tier }
      if ($Tier -in @('Dev', 'Exp')) {
        $parameters['UserName'] = $UserName
      }
      return [string](Get-DbConnectionStringSecretDescriptor @parameters).SecretName
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "DAB MCP secret-name resolution failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Completed DAB MCP secret-name resolution.'
  }
}
