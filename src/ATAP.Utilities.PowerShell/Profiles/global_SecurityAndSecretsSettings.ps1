## variables and locations for security and secret management

$local_SecurityAndSecretsSettings = [ordered]@{

  # Where all things Security and Secrets related are stored on the filesystem
  $global:configRootKeys['SECURE_CLOUD_BASE_PATHConfigRootKey']                                     = 'join-path $global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] "Security"'

  # OpenSSL Environment variables
  $global:configRootKeys['OPENSSL_HOMEConfigRootKey']                                               = 'join-path $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "OpenSSL" '
  $global:configRootKeys['OPENSSL_CONFConfigRootKey']                                               = 'join-path $global:settings[$global:configRootKeys["OPENSSL_HOMEConfigRootKey"]] "AUdefault.cnf" '
  $global:configRootKeys['RANDFILEConfigRootKey']                                                   = 'join-path $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "OpenSSL" "RandomKeySeed" '


  # Related to Certificate Security
  #  In general, places where the files that are used to create vcertifictes are found
  $global:configRootKeys['SecureCertificatesPathConfigRootKey']                                     = 'join-path $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "Certificates" '
  $global:configRootKeys['SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey']            = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesPathConfigRootKey"]] "EncryptionPassPhraseFiles"'
  $global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']                        = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesPathConfigRootKey"]] "EncryptedKeys"'
  $global:configRootKeys['SecureCertificatesCertificateRequestsPathConfigRootKey']                  = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesPathConfigRootKey"]] "CertificateRequests"'
  $global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']                         = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesPathConfigRootKey"]] "Certificates"'
  # Use this if special purpose openSSL configuration files are needed
  $global:configRootKeys['SecureCertificatesOpenSSLConfigsPathConfigRootKey']                       = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesPathConfigRootKey"]] "CertificateRequestConfigs"'
  # Use this if obfuscation of file names is desired
  $global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']                   = '"CrossReference.txt"'

  #  These define where a Certificte Authority (CA) keeps the records of the CSRs it is given, and a copy of each Certificate it creates and signs
  $global:configRootKeys['SecureCertificatesSigningCertificatesPathConfigRootKey']                 = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesPathConfigRootKey"]] "SigningCertificates"'
  #$global:configRootKeys['SecureCertificatesSigningCertificatesPrivateKeysRelativePathConfigRootKey'] = "'PrivateKeys'"
  #$global:configRootKeys['SecureCertificatesSigningCertificatesNewCertificatesRelativePathConfigRootKey'] ="'NewCertificates'"
  $global:configRootKeys['SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey'] = '"CertificateIssuedDB.txt"'
  #$global:configRootKeys['SecureCertificatesSigningCertificatesSerialNumberRelativePathConfigRootKey'] = '"CertificateSerialNumber.txt"'

  # These define the latter portion of certificate-related filename (used as the parameter -BaseFileName)
  $global:configRootKeys['SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey']             = "'CAPassPhraseFile.txt'"
  $global:configRootKeys['SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey']        = "'CAEncryptedPrivateKey.pem'"
  $global:configRootKeys['SecureCertificatesCACertificateBaseFileNameConfigRootKey']                = "'CACertificate.crt'"
  $global:configRootKeys['SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey']      = "'SSLServerPassPhraseFile.txt'"
  $global:configRootKeys['SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey'] = "'SSLServerEncryptedPrivateKey.pem'"
  $global:configRootKeys['SecureCertificatesSSLServerCertificateRequestBaseFileNameConfigRootKey']  = "'SSLServerCertificateRequest.csr'"
  $global:configRootKeys['SecureCertificatesSSLServerCertificateBaseFileNameConfigRootKey']         = "'SSLServerCertificate.crt'"
  $global:configRootKeys['SecureCertificatesCodeSigningPassPhraseFileBaseFileNameConfigRootKey']      = "'CodeSigningPassPhraseFile.txt'"
  $global:configRootKeys['SecureCertificatesCodeSigningEncryptedPrivateKeyBaseFileNameConfigRootKey'] = "'CodeSigningEncryptedPrivateKey.pem'"
  $global:configRootKeys['SecureCertificatesCodeSigningCertificateRequestBaseFileNameConfigRootKey']  = "'CodeSigningCertificateRequest.csr'"
  $global:configRootKeys['SecureCertificatesCodeSigningCertificateBaseFileNameConfigRootKey']         = "'CodeSigningCertificate.crt'"


  # Security
  $global:configRootKeys['SecretVaultExtensionModuleNameConfigRootKey' ]                            = '"SecretManagement.Keepass"'
  $global:configRootKeys['SecretVaultNameConfigRootKey' ]                                           = '"ThisUsersSecretVault"'
  $global:configRootKeys['SecretVaultDescriptionConfigRootKey' ]                                    = '"Secrets stored in a secure vault"'
  $global:configRootKeys['SecretVaultKeySizeIntConfigRootKey' ]                                     = '"32"'
  $global:configRootKeys['SecretVaultPasswordTimeoutConfigRootKey' ]                                = '"300"'
  # SecretManagement global settings
  $global:configRootKeys['SecureCloudVaultPathConfigRootKey']                                       = 'join-path $global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] "SVs"'  #
  $global:configRootKeys['SecureCloudEncryptedSecretsConfigRootKey']                                = 'join-path $global:settings[$global:configRootKeys["CloudBasePathConfigRootKey"]] "Security"'  #
  $global:configRootKeys['EncryptedMasterPasswordsPathConfigRootKey']                               = 'join-path $global:settings[$global:configRootKeys["SecureCloudVaultPathConfigRootKey"]] "OMPs.json" '#
  # $global:configRootKeys['ATAPUtilitiesMasterPasswordsPathConfigRootKey']  = 'join-path $global:settings[$global:configRootKeys["EncryptedMasterPasswordsPathConfigRootKey"]] "AUMPs.txt" '#
  $global:configRootKeys['SecretManagementVaultsPathConfigRootKey']                                 = 'join-path $global:settings[$global:configRootKeys["SecureCloudVaultPathConfigRootKey"]] "SMVPs" '#
  $global:configRootKeys['DataEncryptionCertificatesPathConfigRootKey']                             = 'join-path $global:settings[$global:configRootKeys["SecureCloudVaultPathConfigRootKey"]] "DECs" '#
  $global:configRootKeys['SecretVaultKeyFilePathConfigRootKey']                                     = 'Join-Path $global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] "SecretManagement" "KeyFiles","SecretVaultTestingEncryption.key"'
  $global:configRootKeys['SecretVaultEncryptedPasswordFilePathConfigRootKey']                       = 'Join-Path $global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] "SecretManagement" "EncryptedPasswordFiles","SecretVaultTestingEncryptedPassword.txt"'
  $global:configRootKeys['SecretVaultPathToKeePassDBConfigRootKey']                                 = "Join-Path 'C:' 'KeePass' 'Local.ATAP.Utilities.kdbx'"

  # Place to keep things for Disaster recovery
  $global:ConfigRootKeys['DisasterRecoveryPathConfigRootKey']                                       = "Join-path $global:settings[$global:ConfigRootKeys[SECURE_CLOUD_BASE_PATHConfigRootKey]] 'DisasterRecovery'"
  # ToDo: figure out how to handle USB sticks and what if not plugged in
  $global:ConfigRootKeys['DisasterRecoveryBackupPathConfigRootKey']                                 = "Join-path 'C:' 'DisasterRecovery'"
}

# If a global hash variable already exists, modify the global with the local information
# This supports the ability to have multiple files define these values
if ($global:SecurityAndSecretsSettings) {
  Write-PSFMessage -Level Debug -Message 'global:SecurityAndSecretsSettings are already defined '
  # Load the $global:SecurityAndSecretsSettings with the $Local:SecurityAndSecretsSettings
  $keys = $local_SecurityAndSecretsSettings.Keys
  foreach ($key in $keys ){
    # ToDo error handling if one fails
    $global:SecurityAndSecretsSettings[$key] = $local_SecurityAndSecretsSettings[$key]
  }
}
else {
  Write-PSFMessage -Level Debug -Message 'global:SecurityAndSecretsSettings are NOT defined'
  $global:SecurityAndSecretsSettings = $local_SecurityAndSecretsSettings
}


