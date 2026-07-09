
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-UsersSecretVaultInfo.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Open-UsersSecretVault.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Test-SecretVault.ps1'
$SecretVaultInfo = Get-UsersSecretVaultInfo

Open-UsersSecretVault $SecretVaultInfo

Test-SecretVault -Name $SecretVaultInfo[$global:configRootKeys['SecretVaultNameConfigRootKey' ] ]
