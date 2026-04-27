#Requires -Version 7.0
<#
.SYNOPSIS
    Bootstraps a shell session for the 5-tier publish/promote workflow.
.DESCRIPTION
    Loads PSFramework and dot-sources every public cmdlet from both
    ATAP.Utilities.PowerShell (defines Get-PVal / Get-ParameterValueFromNeoConfigurationRoot)
    and ATAP.Utilities.BuildTooling.PowerShell (Publish / Move-ProGet* / New-Sprint*).

    Run this once per shell session before invoking Invoke-DotnetBuildWithRetry,
    Invoke-ModuleBuildWithRetry, or any Move-ProGetPackage* cmdlet.

.EXAMPLE
    pwsh
    cd C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-98-sprint-0006-work-items
    . ./Initialize-5TierShell.ps1
    Invoke-DotnetBuildWithRetry -SolutionOrProjectPath 'src/ATAP.Utilities.Philote.Interfaces'
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot

Write-Host "[Init] Repo: $repoRoot" -ForegroundColor Cyan

# 1. PSFramework -------------------------------------------------------------
if (-not (Get-Module -Name PSFramework -ListAvailable)) {
    Write-Host '[Init] Installing PSFramework (CurrentUser scope)...' -ForegroundColor Yellow
    Install-Module -Name PSFramework -Scope CurrentUser -Force -AllowClobber
}
Import-Module PSFramework -ErrorAction Stop
Write-Host '[Init] PSFramework loaded' -ForegroundColor Green

# 2. Dot-source every public cmdlet from the two modules --------------------
#    ATAP.Utilities.PowerShell               — defines Get-PVal (alias of
#                                               Get-ParameterValueFromNeoConfigurationRoot)
#    ATAP.Utilities.BuildTooling.PowerShell  — Publish / Move-ProGet* / New-Sprint*
$moduleDirs = @(
    'src\ATAP.Utilities.PowerShell\public',
    'src\ATAP.Utilities.BuildTooling.PowerShell\public'
)
function Test-IsCmdletFile {
    param([string] $Path)
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref] $tokens, [ref] $errors)
    if ($errors -and $errors.Count -gt 0) { return $false }
    $endBlock = $ast.EndBlock
    if ($null -eq $endBlock -or $endBlock.Statements.Count -eq 0) { return $false }
    # File is safe to dot-source if every top-level statement is a function
    # definition. Anything else (Get-ChildItem, Invoke-*, assignments) runs
    # on dot-source and must be skipped.
    foreach ($stmt in $endBlock.Statements) {
        if ($stmt -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
            return $false
        }
    }
    return $true
}

$imported = 0
$skipped  = 0
$failed   = [System.Collections.Generic.List[string]]::new()
foreach ($rel in $moduleDirs) {
    $dir = Join-Path $repoRoot $rel
    if (-not (Test-Path $dir)) {
        $failed.Add("missing folder: $rel")
        continue
    }
    Get-ChildItem -Path $dir -Filter '*.ps1' -File | ForEach-Object {
        $file = $_
        if (-not (Test-IsCmdletFile -Path $file.FullName)) {
            $skipped++
            return
        }
        try {
            . $file.FullName
            $imported++
        } catch {
            $failed.Add("$rel\$($file.Name): $($_.Exception.Message)")
        }
    }
}
$color = $failed.Count ? 'Yellow' : 'Green'
Write-Host "[Init] Cmdlets dot-sourced: $imported ok, $skipped skipped (non-cmdlet scripts), $($failed.Count) failed" `
    -ForegroundColor $color
if ($failed.Count) {
    $failed | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Yellow }
}

# Sanity-check the alias the Publish script depends on
if (Get-Command -Name Get-PVal -ErrorAction SilentlyContinue) {
    Write-Host '[Init] Get-PVal alias resolved' -ForegroundColor Green
} else {
    Write-Host '[Init] WARNING: Get-PVal alias not available after import' -ForegroundColor Red
}

# 4. Secret / env sanity -----------------------------------------------------
if (-not $env:PROGET_ADMIN_API_KEY) {
    Write-Host '[Init] WARNING: PROGET_ADMIN_API_KEY is not set in this shell' -ForegroundColor Red
} else {
    Write-Host '[Init] PROGET_ADMIN_API_KEY present' -ForegroundColor Green
}

Write-Host '[Init] Ready. You can now run Invoke-DotnetBuildWithRetry, Invoke-ModuleBuildWithRetry, or Move-ProGetPackage*' `
    -ForegroundColor Cyan
