# Powershell SecretManagement cannot unlock SecretVault with SecureString read from file
# Powershell SecretManagement how to unlock a SecretVault from
# Install the necessary modules if not yet installed
@('Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore', 'SecretManagement.Keepass') |
ForEach-Object { if (-not (Get-Module $_)) { Install-Module $_ } else { Write-Output "Module already installed: $_" } }

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
$Name = 'ThisUsersSecretVault'
$Description = 'Secrets stored in a secure vault'
$KeySizeInt = 32 # one of 16, 24, or 32. The KeePass module expects 32
$PasswordTimeout = 300 # in seconds
$Encoding = 'utf8' # make sure the encoding is consistent for all persistence files. See Also the $PSDefaultParameters

# The location of the following two persistence files should be two separate secure location protected by ACL lists
# There is a common KeyFile and encryptedPassword per Role that the user-machine pairs perform
# This demo program just uses the environment's temp path.
# For a useable KeePass vault, place it in an accessable synchronized location. Obsufucation can't hurt.
$KeyFilePath = Join-Path 'C:' 'Dropbox' 'SecretManagement','KeyFiles','SecretVaultTestingEncryption.key' # Join-Path $env:TEMP 'SecretVaultTestingEncryption.key'
$EncryptedPasswordFilePath = Join-Path 'C:' 'Dropbox' 'SecretManagement','EncryptedPasswordFiles','SecretVaultTestingEncryptedPassword.txt' # $env:TEMP 'SecretVaultTestingEncryptedPassword.txt'

$PathToKeePassDB = 'C:\KeePass\Local.ATAP.Utilities.kdbx'  # This is the identifier for the KeePassParameterSet
$PathToKeePassDB = 'C:\DropBox\KeePass\Main.Synchronized.ATAP.Utilities.kdbx'  # This is the identifier for the KeePassParameterSet

# Setup the KeyBytes and use them to create a KeyFile, which will be used to encrypt and decrypt a SecureString
# only do this once in a PSSession for demonstrating
#  This is done by a security admin when setting up a new user. It should be placed in a secure location accessable by the new user.
#  For a KeePass vault, the KeyFile should be 32 bytes long, and it should be created once per vault (and rotated regularly)
#  For a KeePass vault, the admin needs to know the plaintext password for the vault, so that they can create an encrypted instance of the KeePass vault's Master Password
if ($false) {
  $EncryptionKeyBytes = New-Object Byte[] $KeySizeInt
  [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptionKeyBytes)
  $EncryptionKeyBytes | Out-File -Encoding $Encoding -FilePath $KeyFilePath
}

# Cleanup prior attempts
Get-SecretVault | Unregister-SecretVault
switch ($ExtensionVaultModuleName) {
  'Microsoft.PowerShell.SecretStore' {
    # Cleanup or create a `'Microsoft.PowerShell.SecretStore'` vault extension
    # THIS WILL ERASE ALL SECRETS in the PowerShell.SecretStore extension vault WITHOUT ASKING FOR CONFIRMATION. FOR AUTOMATION AND DEMO
    Reset-SecretStore -Authentication 'Password' -Interaction 'None' -Password $passwordSecureString -Force
  }
  'SecretManagement.Keepass' {
    # ToDo: ensure the Keepass vault is locked, waiting on feature enhancement to Powershell's SecretManagement.Keepass module
    # Lock-SecretVault TBD
  }
  Default {
    Throw "Unrecognized ExtensionVaultModuleName : $ExtensionVaultModuleName"
  }
}

# Read the KeyFile for an encryption key, and use that to encrypt the passwordSecureString, then persist the encrypted instance of the passwordSecureString to a file.
$EncryptionKeyData = Get-Content -Encoding $Encoding -Path $KeyFilePath
$passwordSecureString | ConvertFrom-SecureString -Key $EncryptionKeyData | Out-File -Encoding $Encoding -FilePath $EncryptedPasswordFilePath

# To validate, re-read the KeyFile, then read the encrypted instance of the passwordSecureString, and convert it to a SecureString
$EncryptionKeyData = Get-Content -Encoding $Encoding -Path $KeyFilePath
$passwordSecureStringFromPersistence = ConvertTo-SecureString -String $(Get-Content -Encoding $Encoding -Path $EncryptedPasswordFilePath) -Key $EncryptionKeyData
# Show that the SecureString that came from persistence converts to the same PlainText password
Write-Host "PasswordPlainText from passwordSecureStringFromPersistence: $(ConvertFrom-SecureString -SecureString $passwordSecureStringFromPersistence -AsPlainText)"

# Is getting the SecureString password from the file repeatable
$EncryptionKeyData2 = Get-Content -Encoding $Encoding -Path $KeyFilePath
$PasswordSecureStringFromPersistence2 = Get-Content -Encoding $Encoding -Path $EncryptedPasswordFilePath | ConvertTo-SecureString -Key $EncryptionKeyData2
Write-Host "PasswordPlainText2 from PasswordSecureStringFromPersistence2: $(ConvertFrom-SecureString -SecureString $PasswordSecureStringFromPersistence2 -AsPlainText)"

# Although they both have the same Plaintext, the two SecureStrings are different objects
if ($passwordSecureStringFromPersistence -eq $PasswordSecureStringFromPersistence2) { 'They ARE Equal' } else { 'They ARE NOT Equal' }
# And to show another way, a bit archaic, of getting the Plaintext from the SecureString
Write-Host "PasswordPlainText3 from PasswordSecureStringFromPersistence2 using InteropServices.marshall: $([System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordSecureStringFromPersistence)))"

switch ($ExtensionVaultModuleName) {
  'Microsoft.PowerShell.SecretStore' {
    $VP = @{Description = 'Secrets stored in a secure vault'; Authentication = 'Password'; Interaction = 'None'; Password = $passwordSecureString; PasswordTimeout = 300 }
    Register-SecretVault -Name 'ThisUsersSecretVault' -ModuleName 'Microsoft.PowerShell.SecretStore' -VaultParameters $VP
  }
  'SecretManagement.Keepass' {
    # Note that the MasterVaultPassword is supplied when registering a 'Microsoft.PowerShell.SecretStore' vault
    $VP = @{Description = $Description; Authentication = 'Password'; Interaction = 'None'; Path = $PathToKeePassDB ; Password = $PasswordSecureStringFromPersistence; PasswordTimeout = $PasswordTimeout; KeyPath = $KeyFilePath }
    Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters $VP
  }
}

# Unlock the vault using it's password, as read in form persistent storage
# ToDo: figure out how to cpature the warnings issued when unlock fails
$success = $false
switch ($ExtensionVaultModuleName) {
  'Microsoft.PowerShell.SecretStore' {
    $success = Unlock-SecretStore -Name $Name -Password $passwordSecureStringFromPersistence  }
  'SecretManagement.Keepass' {
    $success = Unlock-SecretVault -Name $Name -Password $passwordSecureStringFromPersistence  }
}

# Lets see if it is unlocked...
# ToDo: figure out how to capture the warnings issued when Test-SecretVault fails
Test-SecretVault -Name $Name

# Assuming that the vault contains a secret name 'FirstSecret'
$SecretName = 'FirstSecret'
Get-Secret -Name $SecretName -Vault $name

# I am trying to use `Microsoft.PowerShell.SecretManagement`, with a `PowerShell.SecretStore`. I cannot figure out how to use `Unlock-SecretStore` with the `-Password` parameter.

# $Key = New-Object Byte[] 16
# [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
# $EncryptedPassword = ConvertFrom-SecureString -SecureString $SecurePassword1 -Key $Key
# $SecurePassword2 = ConvertTo-SecureString -String $EncryptedPassword -Key $Key
# ConvertFrom-SecureString -SecureString $SecurePassword1 -AsPlaintext
# ConvertFrom-SecureString -SecureString $SecurePassword2 -AsPlaintext
# $SecurePassword1 -eq $SecurePassword2
#
# # Note that the VaultParamter Values need to have double-quotes around them, and the data between the double-quotes should be expanded
# $VPAsStringForInvoke = `@{Description = ""$Description"";  Path = ""$PathToKeePassDB"" }`
# $command = "Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters" + $VPAsStringForInvoke

#$PasswordPlainText = 'PleaseDontEmbedAPlainTextPasswordInAnyScriptFile'
#$PasswordSecureString = ConvertTo-SecureString -String $PasswordPlainText -AsPlainText -Force  # use this line if you want to accept the $PasswordPlainText as the password string

# $PSDefaultParameterValues = @{ '*:Encoding' = 'utf8' }


if ($false) {
  # Use the KeePass Secret Vault. You will need to have a working installation of KeePass on the computer
  #   create a KeePass vault using both a Master Password and a keyfile (make sure to use , and have setup a Master password for the vault
 # many permutations of the Vault Parameters
  # Note that the MasterVaultPassword is not yet used here for registering a 'SecretManagement.Keepass' vault
  #$VP = @{Description = $Description; Path = $PathToKeePassDB; UseMasterPassword = $false;}
  #$VP = @{Description = $Description; Path = $PathToKeePassDB; UseMasterPassword = $true;}
  # Note that the MasterVaultPassword is used following here for registering a 'SecretManagement.Keepass' vault
  #$VP = @{Description = $Description; Path = $PathToKeePassDB; UseMasterPassword = $true; MasterPassword = $PasswordSecureString}
  $VP = @{Description = $Description; Path = $PathToKeePassDB; UseMasterPassword = $true; MasterPassword = $PasswordSecureStringFromPersistence; KeyPath = $KeyFilePath }
  Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters $VP
}
