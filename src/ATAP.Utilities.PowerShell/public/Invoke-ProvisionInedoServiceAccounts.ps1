#Requires -RunAsAdministrator
# Provision SvcProGet and SvcBuildmaster, then grant db_owner on their respective PRODUCTION databases.
# Run with: pwsh -File '..._generated\Invoke-ProvisionInedoServiceAccounts.ps1'

$publicDir = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-98-sprint-0006-work-items\src\ATAP.Utilities.PowerShell\public'

. "$publicDir\Type-PSLSA.ps1"
. "$publicDir\New-LocalServiceAccount.ps1"
. "$publicDir\Initialize-SqlServiceLogin.ps1"

# ---- SvcProGet ---------------------------------------------------------------
Write-Host '--- Creating SvcProGet ---' -ForegroundColor Cyan
Write-Host 'Copy the SvcProGet password to your clipboard, then press Enter...' -ForegroundColor Yellow
$null = Read-Host
$pwProGet = ConvertTo-SecureString (Get-Clipboard) -AsPlainText -Force
$r1 = New-LocalServiceAccount `
  -AccountName SvcProGet `
  -FullName 'ProGet Service Identity' `
  -Description 'Windows service account for Inedo ProGet' `
  -Password $pwProGet `
  -GrantSeServiceLogonRight
$r1 | Format-List

# ---- Grant SvcProGet full control over ProGet package store -----------------
# ProGet UI bulk-delete (and any other write operation on the package store) fails
# with HTTP 500 "Access to path ... is denied" unless SvcProGet holds explicit
# Full Control on C:\ProgramData\ProGet\Packages.  The Inedo Hub installer does NOT
# set this automatically when a custom service account replaces NetworkService.
# See Explainer 0500-New Computer setup.md §7.5 for details.
Write-Host '--- Granting SvcProGet Full Control over ProGet package store ---' -ForegroundColor Cyan
icacls 'C:\ProgramData\ProGet\Packages' /grant 'SvcProGet:(OI)(CI)F' /T
Write-Host "icacls exit code: $LASTEXITCODE" -ForegroundColor $(if ($LASTEXITCODE -eq 0) { 'Green' } else { 'Red' })

# ---- SvcBuildmaster ----------------------------------------------------------
Write-Host '--- Creating SvcBuildmaster ---' -ForegroundColor Cyan
Write-Host 'Copy the SvcBuildmaster password to your clipboard, then press Enter...' -ForegroundColor Yellow
$null = Read-Host
$pwBM = ConvertTo-SecureString (Get-Clipboard) -AsPlainText -Force
$r2 = New-LocalServiceAccount `
  -AccountName SvcBuildmaster `
  -FullName 'BuildMaster Service Identity' `
  -Description 'Windows service account for Inedo BuildMaster' `
  -Password $pwBM `
  -GrantSeServiceLogonRight
$r2 | Format-List

# ---- Grant ProGet db_owner ---------------------------------------------------
Write-Host '--- Granting ProGet db_owner to SvcProGet ---' -ForegroundColor Cyan
$r3 = Initialize-SqlServiceLogin `
  -SqlInstance 'localhost\PRODUCTION' `
  -DatabaseName 'ProGet' `
  -ServiceAccount "$env:COMPUTERNAME\SvcProGet" `
  -Encrypt Optional `
  -TrustServerCertificate
$r3 | Format-List

# ---- Grant BuildMaster db_owner ----------------------------------------------
Write-Host '--- Granting BuildMaster db_owner to SvcBuildmaster ---' -ForegroundColor Cyan
$r4 = Initialize-SqlServiceLogin `
  -SqlInstance 'localhost\PRODUCTION' `
  -DatabaseName 'BuildMaster' `
  -ServiceAccount "$env:COMPUTERNAME\SvcBuildmaster" `
  -Encrypt Optional `
  -TrustServerCertificate
$r4 | Format-List

Write-Host 'Done.' -ForegroundColor Green
