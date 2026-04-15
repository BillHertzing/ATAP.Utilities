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
