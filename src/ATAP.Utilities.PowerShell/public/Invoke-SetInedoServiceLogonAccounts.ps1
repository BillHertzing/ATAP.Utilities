# Import the function (if not already loaded via module)
. "$PSScriptRoot\Set-ServiceLogonAccount.ps1"

Write-Host '=== Set ProGet service logon account ===' -ForegroundColor Cyan
Write-Host 'Copy the SvcProGet password to clipboard, then press Enter...'
$null = Read-Host
$proGetCred = [PSCredential]::new('.\SvcProGet', (ConvertTo-SecureString (Get-Clipboard) -AsPlainText -Force))
Set-ServiceLogonAccount -ServiceName 'INEDOPROGETSVC' -Credential $proGetCred | Format-List

Write-Host '=== Set BuildMaster service logon account ===' -ForegroundColor Cyan
Write-Host 'Copy the SvcBuildmaster password to clipboard, then press Enter...'
$null = Read-Host
$bmCred = [PSCredential]::new('.\SvcBuildmaster', (ConvertTo-SecureString (Get-Clipboard) -AsPlainText -Force))
Set-ServiceLogonAccount -ServiceName 'INEDOBMSVC' -Credential $bmCred | Format-List

Write-Host 'Done. You may need to restart INEDOPROGETSVC and INEDOBMSVC for the new logon to take effect.' -ForegroundColor Green
