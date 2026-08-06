function Start-DabMcpServer {
  <#
  .SYNOPSIS
  Starts Data API Builder as a foreground MCP stdio server.

  .DESCRIPTION
  Starts DAB in its documented stdio transport mode. The connection string is read from
  Bitwarden Secrets Manager immediately before DAB starts and exists only in the child
  process environment. This function deliberately emits no PowerShell output before
  invoking DAB because MCP protocol messages own stdout.

  .OUTPUTS
  None.
  #>
  [CmdletBinding()]
  [OutputType([void])]
  param(
    [string] $ConfigPath = (Join-Path $env:APPDATA 'ATAP\DataApiBuilder\ATAPUtilities\dab-config.json'),

    [ValidateNotNullOrEmpty()]
    [string] $Role = 'mcp-reader',
    [ValidateSet('Production', 'QA', 'Integration', 'Dev', 'Exp')]
    [string] $Tier = 'Exp',

    [ValidateNotNullOrEmpty()]
    [string] $DatabaseHost = $env:COMPUTERNAME,

    [ValidateNotNullOrEmpty()]
    [string] $DatabaseName = 'ATAPUtilities',

    [string] $UserName = $env:USERNAME,

    [string] $ConnectionStringSecretName,

    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*$')]
    [string] $ConnectionStringEnvironmentVariable = 'DAB_ATAPUTILITIES_CONNECTION_STRING'
  )

  begin {
    $fn = 'Start-DabMcpServer'
    $mn = 'ATAP.Utilities.BuildTooling.DotnetBuild.PowerShell'
    $previousConnectionString = $null
    $connectionStringEnvironmentWasSet = $false
  }

  process {
    try {
      if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "DAB config '$ConfigPath' does not exist. Run Initialize-DabMcpConfiguration first."
      }
      if (-not (Get-Command -Name 'Get-SecretATAP' -ErrorAction SilentlyContinue)) {
        Import-Module -Name 'ATAP.Utilities.BuildTooling.Secrets.PowerShell' -DisableNameChecking -WarningAction SilentlyContinue -ErrorAction Stop
      }
      $secretName = if ([string]::IsNullOrWhiteSpace($ConnectionStringSecretName)) {
        Resolve-DabMcpConnectionStringSecretName -Tier $Tier -DatabaseHost $DatabaseHost -DatabaseName $DatabaseName -UserName $UserName
      } else {
        $ConnectionStringSecretName
      }
      $connectionString = Get-SecretATAP -SecretName $secretName -SecretStoreType 'BitwardenSecretsManager'
      if ([string]::IsNullOrWhiteSpace($connectionString)) {
        throw "BWS returned an empty connection string for '$secretName'."
      }
      $previousConnectionString = [Environment]::GetEnvironmentVariable($ConnectionStringEnvironmentVariable, 'Process')
      $connectionStringEnvironmentWasSet = $null -ne $previousConnectionString
      [Environment]::SetEnvironmentVariable($ConnectionStringEnvironmentVariable, $connectionString, 'Process')
      $dab = Get-Command -Name 'dab' -ErrorAction Stop
      & $dab.Source start '--mcp-stdio' "role:$Role" '--config' $ConfigPath '--LogLevel' 'Error'
      if ($LASTEXITCODE -ne 0) {
        throw "DAB MCP server exited with code $LASTEXITCODE."
      }
    }
    catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "DAB MCP server failed. Exception: $($_.Exception.Message)"
      throw
    }
  }

  end {
    if ($connectionStringEnvironmentWasSet) {
      [Environment]::SetEnvironmentVariable($ConnectionStringEnvironmentVariable, $previousConnectionString, 'Process')
    } elseif (-not [string]::IsNullOrWhiteSpace($ConnectionStringEnvironmentVariable)) {
      [Environment]::SetEnvironmentVariable($ConnectionStringEnvironmentVariable, $null, 'Process')
    }
  }
}
