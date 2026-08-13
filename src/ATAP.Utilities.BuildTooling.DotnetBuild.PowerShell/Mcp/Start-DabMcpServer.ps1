[CmdletBinding()]
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
  [string] $ConnectionStringEnvironmentVariable = 'DAB_ATAPUTILITIES_CONNECTION_STRING',

  [ValidatePattern('^http://(127\.0\.0\.1|localhost):[0-9]+$')]
  [string] $McpHostUrl = 'http://127.0.0.1:5105'
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$previousAspNetCoreUrls = [Environment]::GetEnvironmentVariable('ASPNETCORE_URLS', 'Process')

# This process owns an MCP stdio channel. Do not import the full DotnetBuild module:
# its unrelated ProGet dependency can emit host warnings before DAB writes JSON-RPC.
Import-Module -Name 'ATAP.Utilities.BuildTooling.Secrets.PowerShell' `
  -DisableNameChecking `
  -WarningAction SilentlyContinue `
  -InformationAction SilentlyContinue `
  -ErrorAction Stop

try {
  . (Join-Path $PSScriptRoot '..\private\Resolve-DabMcpConnectionStringSecretName.ps1')
  . (Join-Path $PSScriptRoot '..\public\Start-DabMcpServer.ps1')

  # DAB starts Kestrel even in MCP stdio mode. A distinct loopback endpoint keeps
  # this process from colliding with the normal DAB host or another tier's MCP server.
  [Environment]::SetEnvironmentVariable('ASPNETCORE_URLS', $McpHostUrl, 'Process')
  $startParameters = @{} + $PSBoundParameters
  [void]$startParameters.Remove('McpHostUrl')
  Start-DabMcpServer @startParameters
}
finally {
  [Environment]::SetEnvironmentVariable('ASPNETCORE_URLS', $previousAspNetCoreUrls, 'Process')
}
