# Powershell SecretManagement how to unlock a SecretVault from

# Select an extension vault module
$ExtensionVaultModuleName = 'SecretManagement.Keepass'
#$ExtensionVaultModuleName = 'Microsoft.PowerShell.SecretStore'
Write-Host "ExtensionVaultModuleName is '$ExtensionVaultModuleName'"

# Get a password from the user
Write-Host 'enter a password, hit enter, this program is not secure, it will echo back the password you enter (more than once :-))'
Write-Host 'if using KeePass, type in the KeePass Master Vault Password'
$passwordSecureString = Read-Host -AsSecureString
Write-Host $passwordSecureString # Will just display the Securestring type name
# show the PlainText password from the $passwordSecureString
Write-Host "PasswordPlainText from passwordSecureString: $(ConvertFrom-SecureString -SecureString $passwordSecureString -AsPlainText)"

# Prepare some parameters. The following are in the DefaultParameterSet
$VaultName = 'DemoSecretVault'
$Description = 'Secrets stored in a secure vault'
$KeySizeInt = 32 # one of 16, 24, or 32. The KeePass module expects 32
$PasswordTimeout = 300 # in seconds
$Encoding = 'utf8' # make sure the encoding is consistent for all persistence files. See Also the $PSDefaultParameters

# The location of the following two persistence files should be two separate secure location protected by ACL lists
# There is a common KeyFile and encryptedPassword per Role that the user-machine pairs perform
# This demo program just uses the environment's temp path.
# For a useable KeePass vault, place it in an accessable synchronized location. Obsufucation can't hurt.
$KeyFilePath = Join-Path 'C:' 'Dropbox' 'Security','Vaults','KeyFiles','DemoVaultKeyFile.key' # Join-Path $env:TEMP 'SecretVaultTestingEncryption.key'
$EncryptedPasswordFilePath = Join-Path 'C:' 'Dropbox' 'Security','Vaults','PasswordFiles','DemoVaultEncryptedPassword.txt' # $env:TEMP 'SecretVaultTestingEncryptedPassword.txt'

$PathToKeePassDB = 'C:\KeePass\Local.ATAP.Utilities.kdbx'  # This is the identifier for the KeePassParameterSet
$PathToKeePassDB = 'C:\DropBox\KeePass\Main.Synchronized.ATAP.Utilities.kdbx'  # This is the identifier for the KeePassParameterSet
$PathToKeePassDB = Join-Path 'C:' 'Dropbox' 'Security','Vaults','VaultDatabases','Demo','Demo.ATAP.Utilities.kdbx'


# The KeyfilePath file will be used to encrypt and decrypt a SecureString (the Vault's MasterPassword)
# The KeyfilePath file must be created before the creation of the KeePass Vault
# This is done by a security admin when setting up a new Vault. It should be placed in a secure location accessable by aall users of the vault.
# this step, in the demo, includes a pause after creating the file so that the Demo KeePass Vault can be created. Make note of the Master Password used in the vault creation
# For a KeePass vault, the KeyFile should be 32 bytes long
#  All vaults should have the KeyFile and MasterPassword rotated regularly
if ($true) {
  . "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-SecureStringKeyFile.ps1"
  New-SecureStringKeyFile -KeyFilePath $KeyFilePath -KeySizeInt $KeySizeInt
}

Write-PSFMessage -Level Important -Message "KeyFilePath = $KeyFilePath"

# Read the KeyFile for an encryption key, and use that to encrypt the passwordSecureString, then persist the encrypted instance of the passwordSecureString to a file.
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-SecureStringMasterPasswordFile.ps1'
New-SecureStringMasterPasswordFile -PasswordSecureString $PasswordSecureString -PasswordFilePath $EncryptedPasswordFilePath -KeyFilePath $KeyFilePath -Encoding $Encoding

# Clean up or setup the extension vault
switch ($ExtensionVaultModuleName) {
  'Microsoft.PowerShell.SecretStore' {
    # Cleanup or create a `'Microsoft.PowerShell.SecretStore'` vault extension
    # THIS WILL ERASE ALL SECRETS in the PowerShell.SecretStore extension vault WITHOUT ASKING FOR CONFIRMATION. FOR AUTOMATION AND DEMO
    Reset-SecretStore -Authentication 'Password' -Interaction 'None' -Password $passwordSecureString -Force
}
'SecretManagement.Keepass' {
  $PasswordFromHostPrompt = Read-Host -Prompt "Enter the full path to the DemoVault [$PathToKeePassDB]"
  if (-not [string]::IsNullOrWhiteSpace($PasswordFromHostPrompt))  {
    if (-not (test-path $_)) {
      throw "file not found: $PasswordFromHostPrompt"
    }
    $PathToKeePassDB = $PasswordFromHostPrompt
  }
}
Default {
  Throw "Unrecognized ExtensionVaultModuleName : $ExtensionVaultModuleName"
}
}

# unregister any exisitng vault
Get-SecretVault | Unregister-SecretVault

# Demo Vault setup ended

# Demo Vault useage

# Register the Demo Vault as the current Secret vault
$PathToKeePassDB = $PathToKeePassDB
$PasswordFilePath = $EncryptedPasswordFilePath
$KeyFilePath = $KeyFilePath
$Password = ConvertTo-SecureString -String $(Get-Content -Encoding $Encoding -Path $PasswordFilePath) -Key $(Get-Content -Encoding $Encoding -Path $KeyFilePath)
Write-Host "PlainText Password: $(ConvertFrom-SecureString -SecureString $Password -AsPlainText)"

# Is getting the SecureString password from the file repeatable
# $EncryptionKeyData2 = Get-Content -Encoding $Encoding -Path $KeyFilePath
# $PasswordSecureStringFromPersistence2 = Get-Content -Encoding $Encoding -Path $EncryptedPasswordFilePath | ConvertTo-SecureString -Key $EncryptionKeyData2
# Write-Host "PasswordPlainText2 from PasswordSecureStringFromPersistence2: $(ConvertFrom-SecureString -SecureString $PasswordSecureStringFromPersistence2 -AsPlainText)"

# Although they both have the same Plaintext, the two SecureStrings are different objects
# if ($passwordSecureStringFromPersistence -eq $PasswordSecureStringFromPersistence2) { 'They ARE Equal' } else { 'They ARE NOT Equal' }
# And to show another way, a bit archaic, of getting the Plaintext from the SecureString
# Write-Host "PasswordPlainText3 from PasswordSecureStringFromPersistence2 using InteropServices.marshall: $([System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordSecureStringFromPersistence)))"

    # Note that the MasterVaultPassword is supplied when registering a 'Microsoft.PowerShell.SecretStore' vault
    $VP = @{Description = $SecretVaultDescription; Authentication = 'Password'; Interaction = 'None'; Password = $Password; PasswordTimeout = $PasswordTimeout }
switch ($ExtensionVaultModuleName) {
  'Microsoft.PowerShell.SecretStore' {
    # $VP = @{Description = $SecretVaultDescription; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }
  }
  'SecretManagement.Keepass' {
    $VP += @{Path = $PathToKeePassDB; KeyPath = $KeyFilePath }
  }
}

# Register the extension vault as the SecretStore
Register-SecretVault -Name $VaultName -ModuleName $ExtensionVaultModuleName -VaultParameters $VP

# Unlock the vault using it's password, as read in from persistent storage
Unlock-SecretVault -Name $VaultName -Password $PasswordSecureString

# Validate the vault is unlocked
$success = Test-SecretVault -Name $VaultName
if (! $Success) {
  Write-PSFMessage -Level Error -Message "Could not unlock SecretVault $VaultName" -Tag 'Security'
  throw "Could not unlock SecretVault $VaultName"
}

# add a secret
$SecretName = 'DemoVaultSecret1'
$SecretValue1 = "This is a the DemoVaultSecret1 string"
Set-Secret -Name $SecretName -Vault $VaultName -Secret $SecretValue1

# retrieve a secret
$SecretValue1Retrieved = Get-Secret -Name $SecretName -Vault $VaultName -AsPlainText

# validate they are the same
if ($passwordSecureStringFromPersistence -eq $PasswordSecureStringFromPersistence2) {
  Write-PSFMessage -Level Important -Message "SecretValue1 $SecretValue1 IS the same as SecretValue1Retrieved $SecretValue1Retrieved"
} else {
  Write-PSFMessage -Level Important -Message "SecretValue1 $SecretValue1 Is NOT the same as SecretValue1Retrieved $SecretValue1Retrieved"
  }

# delete a secret

# validate the secret is gone
# $PSDefaultParameterValues = @{ '*:Encoding' = 'utf8' }

