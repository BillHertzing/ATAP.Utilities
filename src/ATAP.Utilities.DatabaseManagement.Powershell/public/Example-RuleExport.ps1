<#
.SYNOPSIS
    Example script demonstrating how to use the Export-RuleToTextFile function.

.DESCRIPTION
    This script shows various usage scenarios for exporting Rules from the
    ATAPUtilities database to text files. It includes examples of basic usage,
    batch exports, and error handling.

.NOTES
    Before running this script:
    1. Ensure the ATAPUtilities database is accessible
    2. Ensure the stored procedure dbo.GetRuleByName exists (run Flyway migrations)
    3. Install dbatools if not already present: Install-Module -Name dbatools
#>

# Import the Export-RuleToTextFile function
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$functionPath = Join-Path $scriptPath "Export-RuleToTextFile.ps1"

if (Test-Path $functionPath) {
  . $functionPath
  Write-Host "Loaded Export-RuleToTextFile function" -ForegroundColor Green
}
else {
  Write-Error "Could not find Export-RuleToTextFile.ps1 at: $functionPath"
  exit 1
}

# Configuration
$OutputDirectory = "C:\Temp\RuleExports"
$SqlInstance = "localhost"
$DatabaseName = "ATAPUtilities"

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDirectory)) {
  New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
  Write-Host "Created output directory: $OutputDirectory" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Rule Export Examples" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ============================================================================
# EXAMPLE 1: Export a single C# rule with auto-generated filename
# ============================================================================
Write-Host "EXAMPLE 1: Export C# source file rule (auto-generated filename)" -ForegroundColor Yellow
try {
  $outputFile = Export-RuleToTextFile -RuleName "<cs-source-file>" `
    -LanguageKind "CSharp" `
    -SqlInstance $SqlInstance `
    -DatabaseName $DatabaseName `
    -Verbose

  if ($null -ne $outputFile) {
    Write-Host "  Success! File created: $outputFile" -ForegroundColor Green
  }
}
catch {
  Write-Host "  Error: $_" -ForegroundColor Red
}

Write-Host ""

# ============================================================================
# EXAMPLE 2: Export a rule with custom output path
# ============================================================================
Write-Host "EXAMPLE 2: Export using directive rule (custom path)" -ForegroundColor Yellow
try {
  $customPath = Join-Path $OutputDirectory "UsingDirectiveRule.txt"
  $outputFile = Export-RuleToTextFile -RuleName "<using-directive>" `
    -LanguageKind "CSharp" `
    -OutputPath $customPath `
    -SqlInstance $SqlInstance `
    -DatabaseName $DatabaseName

  if ($null -ne $outputFile) {
    Write-Host "  Success! File created: $outputFile" -ForegroundColor Green
  }
}
catch {
  Write-Host "  Error: $_" -ForegroundColor Red
}

Write-Host ""

# ============================================================================
# EXAMPLE 3: Batch export multiple rules
# ============================================================================
Write-Host "EXAMPLE 3: Batch export multiple rules" -ForegroundColor Yellow

# Define rules to export (adjust these based on what exists in your database)
$rulesToExport = @(
  @{ Name = "<cs-source-file>"; Language = "CSharp" }
  @{ Name = "<using-directive>"; Language = "CSharp" }
  # Add more rules as needed based on your database content
)

$successCount = 0
$failCount = 0

foreach ($rule in $rulesToExport) {
  try {
    Write-Host "  Exporting: $($rule.Name) ($($rule.Language))..." -NoNewline

    $sanitizedName = $rule.Name -replace '[<>:"/\\|?*]', '_'
    $outputPath = Join-Path $OutputDirectory "${sanitizedName}_$($rule.Language).txt"

    $result = Export-RuleToTextFile -RuleName $rule.Name `
      -LanguageKind $rule.Language `
      -OutputPath $outputPath `
      -SqlInstance $SqlInstance `
      -DatabaseName $DatabaseName `
      -ErrorAction Stop

    if ($null -ne $result) {
      Write-Host " OK" -ForegroundColor Green
      $successCount++
    }
    else {
      Write-Host " NOT FOUND" -ForegroundColor Yellow
    }
  }
  catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "    Error: $_" -ForegroundColor Red
    $failCount++
  }
}

Write-Host "`n  Batch Summary: $successCount succeeded, $failCount failed" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# EXAMPLE 4: List all available rules in the database
# ============================================================================
Write-Host "EXAMPLE 4: List all available rules in the database" -ForegroundColor Yellow
try {
  # Import dbatools if needed
  if (-not (Get-Module -Name dbatools)) {
    Import-Module dbatools -ErrorAction Stop
  }

  # Configure dbatools
  Set-DbatoolsConfig -FullName sql.connection.trustcert -Value $true -PassThru | Register-DbatoolsConfig -ErrorAction SilentlyContinue
  Set-DbatoolsConfig -FullName sql.connection.encrypt -Value $false -PassThru | Register-DbatoolsConfig -ErrorAction SilentlyContinue

  $query = @"
SELECT
    r.Name AS RuleName,
    plk.Name AS LanguageKind,
    r.PhiloteId,
    p.CreatedAt
FROM dbo.[Rule] r
    INNER JOIN dbo.Philote p ON r.PhiloteId = p.PhiloteId
    INNER JOIN dbo.PrimitiveLanguageKind plk ON r.PrimitiveLanguageKindId = plk.PrimitiveLanguageKindId
ORDER BY plk.Name, r.Name;
"@

  $rules = Invoke-DbaQuery -SqlInstance $SqlInstance `
    -Database $DatabaseName `
    -Query $query `
    -As PSObject

  if ($rules.Count -gt 0) {
    Write-Host "`n  Found $($rules.Count) rule(s) in the database:" -ForegroundColor Green
    Write-Host ""

    $rules | Format-Table -Property RuleName, LanguageKind, PhiloteId, CreatedAt -AutoSize

    Write-Host "  Tip: Copy any RuleName above and use it with Export-RuleToTextFile" -ForegroundColor Cyan
  }
  else {
    Write-Host "  No rules found in the database. Ensure data has been loaded." -ForegroundColor Yellow
  }
}
catch {
  Write-Host "  Error listing rules: $_" -ForegroundColor Red
}

Write-Host ""

# ============================================================================
# EXAMPLE 5: Error handling - non-existent rule
# ============================================================================
Write-Host "EXAMPLE 5: Error handling for non-existent rule" -ForegroundColor Yellow
try {
  Write-Host "  Attempting to export non-existent rule..." -NoNewline

  $result = Export-RuleToTextFile -RuleName "NonExistentRule" `
    -SqlInstance $SqlInstance `
    -DatabaseName $DatabaseName `
    -WarningAction SilentlyContinue

  if ($null -eq $result) {
    Write-Host " Handled gracefully (returned null)" -ForegroundColor Green
  }
}
catch {
  Write-Host " Exception caught: $_" -ForegroundColor Red
}

Write-Host ""

# ============================================================================
# Summary
# ============================================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Examples Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Output files are located in: $OutputDirectory" -ForegroundColor Green
Write-Host ""
Write-Host "To view exported files:" -ForegroundColor Cyan
Write-Host "  Get-ChildItem '$OutputDirectory' | Select-Object Name, Length, LastWriteTime" -ForegroundColor White
Write-Host ""
Write-Host "To open an exported file:" -ForegroundColor Cyan
Write-Host "  notepad.exe (Join-Path '$OutputDirectory' 'filename.txt')" -ForegroundColor White
Write-Host ""
