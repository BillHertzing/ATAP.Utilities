<#
.SYNOPSIS
    Test the GitHub MCP server connection

.DESCRIPTION
    Verifies that the GitHub MCP server is properly configured and can connect to GitHub APIs

.EXAMPLE
    .\src\ATAP.Utilities.BuildTooling.PowerShell\tools\Test-GitHubMCP.ps1

    Tests the MCP server configuration
#>

Write-Host "`n=== GitHub MCP Connection Test ===" -ForegroundColor Cyan
Write-Host ""

$repoRoot = $null
try {
  $gitRoot = & git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
    $repoRoot = ([string]$gitRoot).Trim()
  }
}
catch {
  $repoRoot = $null
}

if ([string]::IsNullOrWhiteSpace($repoRoot)) {
  $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

$setupScriptPath = Join-Path $PSScriptRoot 'Setup-GitHubMCP.ps1'

# Check if GITHUB_TOKEN is set
Write-Host "1. Checking GITHUB_TOKEN environment variable..." -ForegroundColor Yellow
$token = $env:GITHUB_TOKEN
if (-not $token) {
  $token = [System.Environment]::GetEnvironmentVariable('GITHUB_TOKEN', [System.EnvironmentVariableTarget]::User)
}

if ($token) {
  Write-Host "   ✓ GITHUB_TOKEN is set (length: $($token.Length) characters)" -ForegroundColor Green
}
else {
  Write-Host "   ✗ GITHUB_TOKEN is not set" -ForegroundColor Red
  Write-Host "`n   Run: & '$setupScriptPath' -Token 'your_token_here'" -ForegroundColor Yellow
  Write-Host ""
  exit 1
}

# Check if mcp-server-github is available
Write-Host "`n2. Checking mcp-server-github command..." -ForegroundColor Yellow
$mcpCommand = Get-Command mcp-server-github -ErrorAction SilentlyContinue
if ($mcpCommand) {
  Write-Host "   ✓ mcp-server-github found at: $($mcpCommand.Source)" -ForegroundColor Green
}
else {
  Write-Host "   ✗ mcp-server-github not found in PATH" -ForegroundColor Red
  Write-Host "`n   Run: npm install -g @modelcontextprotocol/server-github" -ForegroundColor Yellow
  Write-Host ""
  exit 1
}

# Check VS Code settings
Write-Host "`n3. Checking VS Code settings..." -ForegroundColor Yellow
$settingsPath = Join-Path $repoRoot '.vscode\settings.json'
if (Test-Path $settingsPath) {
  $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
  if ($settings.'mcp.servers'.github) {
    Write-Host "   ✓ MCP server configured in VS Code settings" -ForegroundColor Green
    Write-Host "     Settings: $settingsPath" -ForegroundColor Gray
    Write-Host "     Command: $($settings.'mcp.servers'.github.command)" -ForegroundColor Gray
    Write-Host "     Args: $($settings.'mcp.servers'.github.args -join ' ')" -ForegroundColor Gray
  }
  else {
    Write-Host "   ⚠ MCP server not found in VS Code settings" -ForegroundColor Yellow
  }
}
else {
  Write-Host "   ⚠ VS Code settings.json not found at: $settingsPath" -ForegroundColor Yellow
}

# Test GitHub API access
Write-Host "`n4. Testing GitHub API access..." -ForegroundColor Yellow
try {
  $headers = @{
    'Authorization' = "Bearer $token"
    'Accept'        = 'application/vnd.github.v3+json'
    'User-Agent'    = 'PCMSC-MCP-Test'
  }

  $response = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers -ErrorAction Stop
  Write-Host "   ✓ Successfully authenticated as: $($response.login)" -ForegroundColor Green
  Write-Host "     Name: $($response.name)" -ForegroundColor Gray
  Write-Host "     Public repos: $($response.public_repos)" -ForegroundColor Gray

  # Check rate limit
  $rateLimit = Invoke-RestMethod -Uri 'https://api.github.com/rate_limit' -Headers $headers
  $remaining = $rateLimit.rate.remaining
  $limit = $rateLimit.rate.limit
  Write-Host "`n   Rate limit: $remaining / $limit remaining" -ForegroundColor Gray
}
catch {
  Write-Host "   ✗ Failed to authenticate with GitHub API" -ForegroundColor Red
  Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host ""
  exit 1
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "✓ GitHub MCP is properly configured!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Restart VS Code (if not already done)"
Write-Host "2. Open GitHub Copilot Chat"
Write-Host "3. Try asking: 'What are my GitHub repositories?'"
Write-Host ""
Write-Host "For more help, see: SolutionDocumentation/NewComputerSetup.md"
Write-Host ""
