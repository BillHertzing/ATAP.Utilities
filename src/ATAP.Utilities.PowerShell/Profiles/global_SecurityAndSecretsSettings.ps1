## variables and locations for security and secret management


$local:SecurityAndSecretsSettings = [ordered]@{

  # Where all things Security and Secrets related are stored
  $global:configRootKeys['SECURE_CLOUD_BASE_PATHConfigRootKey']                              = 'join-path $global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] "Security"'  #

  # OpenSSL Environment variables
  $global:configRootKeys['OPENSSL_HOMEConfigRootKey']                                        = 'join-path $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "OpenSSL" '
  $global:configRootKeys['OPENSSL_CONFConfigRootKey']                                        = 'join-path $global:settings[$global:configRootKeys["OPENSSL_HOMEConfigRootKey"]] "AUdefault.cnf" '
  $global:configRootKeys['RANDFILEConfigRootKey']                                            = 'join-path $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "OpenSSL" "RandomKeySeed" '


  # Related to Certificate Security
  #  In general, places where the files that are used to create vcertifictes are found
  $global:configRootKeys['CertificateSecurityBasePathConfigRootKey']                         = 'join-path $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "Certificates" '
  $global:configRootKeys['CertificateSecurityCrossReferenceDNFileConfigRootKey']             = '"CrossReference.txt"'
  $global:configRootKeys['CertificateSecurityDNFilePathReplacementPatternConfigRootKey']     = '"{0}_{1}"'
  $global:configRootKeys['CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey'] = 'join-path $global:settings[$global:configRootKeys["CertificateSecurityBasePathConfigRootKey"]] "EncryptionPassPhraseFiles"'
  $global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']                = 'join-path $global:settings[$global:configRootKeys["CertificateSecurityBasePathConfigRootKey"]] "EncryptedKeys"'
  $global:configRootKeys['CertificateSecurityCertificateRequestConfigsPathConfigRootKey']    = 'join-path $global:settings[$global:configRootKeys["CertificateSecurityBasePathConfigRootKey"]] "CertificateRequestConfigs"'
  $global:configRootKeys['CertificateSecurityCertificateRequestsPathConfigRootKey']          = 'join-path $global:settings[$global:configRootKeys["CertificateSecurityBasePathConfigRootKey"]] "CertificateRequests"'
  $global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']                 = 'join-path $global:settings[$global:configRootKeys["CertificateSecurityBasePathConfigRootKey"]] "Certificates"'

  #  These define where a CertificteAuthority (CA) keeps the records of the CSRs it is given, and a copy of each Certificate it creates and signs
  $global:configRootKeys['CertificateSecuritySigningCertificatesPathConfigRootKey']                       = 'join-path $global:settings[$global:configRootKeys["CertificateSecurityBasePathConfigRootKey"]] "SigningCertificates"'
  $global:configRootKeys['CertificateSecurityCertificateSerialNumberPathConfigRootKey']      = 'join-path $global:settings[$global:configRootKeys["CertificateSecuritySigningCertificatesPathConfigRootKey"]] "CertificateSerialNumber.txt"'
  $global:configRootKeys['CertificateSecurityCertificateIssuedDBPathConfigRootKey']          = 'join-path $global:settings[$global:configRootKeys["CertificateSecuritySigningCertificatesPathConfigRootKey"]] "CertificateIssuedDB"'

  # Security
  $global:configRootKeys['SecretVaultExtensionModuleNameConfigRootKey' ]                     = '"SecretManagement.Keepass"'
  $global:configRootKeys['SecretVaultNameConfigRootKey' ]                                    = '"ThisUsersSecretVault"'
  $global:configRootKeys['SecretVaultDescriptionConfigRootKey' ]                             = '"Secrets stored in a secure vault"'
  $global:configRootKeys['SecretVaultKeySizeIntConfigRootKey' ]                              = '"32"'
  $global:configRootKeys['SecretVaultPasswordTimeoutConfigRootKey' ]                         = '"300"'
  # SecretManagement global settings
  $global:configRootKeys['SecureCloudVaultPathConfigRootKey']                                = 'join-path $global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] "SVs"'  #
  $global:configRootKeys['SecureCloudEncryptedSecretsConfigRootKey']                         = 'join-path $global:settings[$global:configRootKeys["CloudBasePathConfigRootKey"]] "Security"'  #
  $global:configRootKeys['EncryptedMasterPasswordsPathConfigRootKey']                        = 'join-path $global:settings[$global:configRootKeys["SecureCloudVaultPathConfigRootKey"]] "OMPs.json" '#
  # $global:configRootKeys['ATAPUtilitiesMasterPasswordsPathConfigRootKey']  = 'join-path $global:settings[$global:configRootKeys["EncryptedMasterPasswordsPathConfigRootKey"]] "AUMPs.txt" '#
  $global:configRootKeys['SecretManagementVaultsPathConfigRootKey']                          = 'join-path $global:settings[$global:configRootKeys["SecureCloudVaultPathConfigRootKey"]] "SMVPs" '#
  $global:configRootKeys['DataEncryptionCertificatesPathConfigRootKey']                      = 'join-path $global:settings[$global:configRootKeys["SecureCloudVaultPathConfigRootKey"]] "DECs" '#
  $global:configRootKeys['SecretVaultKeyFilePathConfigRootKey']                              = 'Join-Path $global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] "SecretManagement" "KeyFiles","SecretVaultTestingEncryption.key"'
  $global:configRootKeys['SecretVaultEncryptedPasswordFilePathConfigRootKey']                = 'Join-Path $global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] "SecretManagement" "EncryptedPasswordFiles","SecretVaultTestingEncryptedPassword.txt"'
  $global:configRootKeys['SecretVaultPathToKeePassDBConfigRootKey']                          = "Join-Path 'C:' 'KeePass' 'Local.ATAP.Utilities.kdbx'"

  #Place to keep thihngs for Disaster recovery
  $global:ConfigRootKeys['DisasterRecoveryPathConfigRootKey']                                = "Join-path $global:settings[$global:ConfigRootKeys[SECURE_CLOUD_BASE_PATHConfigRootKey]] 'DisasterRecovery'"
  # ToDo: figure out how to handle USB sticks and what if not plugged in
  $global:ConfigRootKeys['DisasterRecoveryBackupPathConfigRootKey']                          = "Join-path 'C:' 'DisasterRecovery'"
}

# If a global variable already exists, append the local information
# This supports the ability to have multiple files define these values
if ($global:SecurityAndSecretsSettings) {
  # Load the $global:SecurityAndSecretsSettings with the $Local:SecurityAndSecretsSettings
  $global:SecurityAndSecretsSettings.Keys | ForEach-Object {
    # ToDo error hanlding if one fails
    $global:SecurityAndSecretsSettings[$_] = $local:SecurityAndSecretsSettings[$_] # Invoke-Expression $global:SecurityAndSecretsSettings[$_]
  }
}
else {
  Write-PSFMessage -Level Debug -Message 'global:SecurityAndSecretsSettings not defined '
  $global:SecurityAndSecretsSettings = $Local:SecurityAndSecretsSettings
}


