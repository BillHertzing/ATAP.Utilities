<#
.SYNOPSIS
    Helper script to configure GitHub MCP (Model Context Protocol) for VS Code

.DESCRIPTION
    This script helps set up the GitHub Personal Access Token for the MCP server.
    It validates the token format and sets it as a user environment variable.

.PARAMETER Token
    Your GitHub Personal Access Token (PAT). Must start with 'ghp_', 'github_pat_', or 'gho_'

.PARAMETER Scope
    The scope for the environment variable. Valid values: 'User', 'Process'
    Default: 'User' (persistent across sessions)

.EXAMPLE
    .\Setup-GitHubMCP.ps1 -Token "ghp_yourtokenhere"

    Sets the GITHUB_TOKEN environment variable for the current user

.EXAMPLE
    .\Setup-GitHubMCP.ps1 -Token "ghp_yourtokenhere" -Scope Process

    Sets the GITHUB_TOKEN for the current PowerShell session only

.NOTES
    Author: GitHub Copilot
    Date: October 14, 2025

    Security: Never commit this script with a hardcoded token!
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, HelpMessage = "Enter your GitHub Personal Access Token")]
  [ValidateNotNullOrEmpty()]
  [string]$Token,

  [Parameter(Mandatory = $false)]
  [ValidateSet('User', 'Process')]
  [string]$Scope = 'User'
)

# Validate token format
function Test-GitHubToken {
  param([string]$Token)

  $validPrefixes = @('ghp_', 'github_pat_', 'gho_', 'ghs_', 'ghr_')
  $isValid = $false

  foreach ($prefix in $validPrefixes) {
    if ($Token.StartsWith($prefix)) {
      $isValid = $true
      break
    }
  }

  if (-not $isValid) {
    Write-Warning "Token doesn't match expected GitHub PAT format"
    Write-Warning "Expected prefixes: $($validPrefixes -join ', ')"
    $continue = Read-Host "Continue anyway? (y/N)"
    return ($continue -eq 'y' -or $continue -eq 'Y')
  }

  return $true
}

# Main execution
Write-Host "`n=== GitHub MCP Setup Helper ===" -ForegroundColor Cyan
Write-Host "This script will configure the GITHUB_TOKEN environment variable`n"

# Validate token
if (-not (Test-GitHubToken -Token $Token)) {
  Write-Error "Token validation failed. Exiting."
  exit 1
}

# Set environment variable
try {
  if ($Scope -eq 'User') {
    [System.Environment]::SetEnvironmentVariable('GITHUB_TOKEN', $Token, [System.EnvironmentVariableTarget]::User)
    Write-Host "✓ GITHUB_TOKEN set for User scope (persistent)" -ForegroundColor Green
    Write-Host "  Token will be available in future PowerShell/VS Code sessions" -ForegroundColor Gray
    Write-Host "`n  ⚠️  Please restart VS Code for changes to take effect" -ForegroundColor Yellow
  }
  else {
    $env:GITHUB_TOKEN = $Token
    Write-Host "✓ GITHUB_TOKEN set for Process scope (current session only)" -ForegroundColor Green
    Write-Host "  Token is available in this PowerShell session" -ForegroundColor Gray
  }

  # Verify it's set
  $verifyToken = if ($Scope -eq 'User') {
    [System.Environment]::GetEnvironmentVariable('GITHUB_TOKEN', [System.EnvironmentVariableTarget]::User)
  }
  else {
    $env:GITHUB_TOKEN
  }

  if ($verifyToken) {
    Write-Host "`n✓ Verification: Token is set (length: $($verifyToken.Length) characters)" -ForegroundColor Green
  }
  else {
    Write-Warning "Could not verify token was set"
  }
}
catch {
  Write-Error "Failed to set environment variable: $_"
  exit 1
}

# Test MCP server
Write-Host "`n=== Testing MCP Server ===" -ForegroundColor Cyan
Write-Host "Checking if mcp-server-github is available...`n"

$mcpCommand = Get-Command mcp-server-github -ErrorAction SilentlyContinue
if ($mcpCommand) {
  Write-Host "✓ mcp-server-github found at: $($mcpCommand.Source)" -ForegroundColor Green

  Write-Host "`nTo test the server manually, run:" -ForegroundColor Cyan
  Write-Host "  mcp-server-github --read-only" -ForegroundColor White
}
else {
  Write-Warning "mcp-server-github command not found in PATH"
  Write-Host "`nTry running: npm list -g @modelcontextprotocol/server-github" -ForegroundColor Yellow
  Write-Host "Or add npm global bin to PATH: " -ForegroundColor Yellow

  $npmPrefix = npm config get prefix 2>$null
  if ($npmPrefix) {
    Write-Host "  $npmPrefix" -ForegroundColor White
  }
}

# Next steps
Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Restart VS Code to load the new environment variable"
Write-Host "2. Open GitHub Copilot Chat"
Write-Host "3. Try asking: 'List my GitHub repositories'"
Write-Host "`nFor more information, see: Documentation/GitHub-MCP-Setup.md"
Write-Host ""
