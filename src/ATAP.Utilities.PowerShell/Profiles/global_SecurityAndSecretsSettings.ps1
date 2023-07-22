## variables and locations for security and secret management

$local_SecurityAndSecretsSettings = @{

  # Where all things Security and Secrets related are stored on the filesystem
  $global:configRootKeys['SECURE_CLOUD_BASE_PATHConfigRootKey']                                                = 'join-path $global:settings[$global:configRootKeys["DropBoxBasePathConfigRootKey"]] "Security"' #' 'join-path $global:settings[$global:settings[$global:configRootKeys["CloudBasePathConfigRootKey"]]] "Security"' #! indirect!

  # OpenSSL Environment variables
  $global:configRootKeys['OPENSSL_HOMEConfigRootKey']                                                          = 'join-path $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "OpenSSL"'
  $global:configRootKeys['OPENSSL_CONFConfigRootKey']                                                          = 'join-path $global:settings[$global:configRootKeys["OPENSSL_HOMEConfigRootKey"]] "AUdefault.cnf"'
  $global:configRootKeys['RANDFILEConfigRootKey']                                                              = 'join-path $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "OpenSSL" "RandomKeySeed"'


  # Related to Certificate Security
  #  In general, places where the files that are used to create certifictes are found
  $global:configRootKeys['SecureCertificatesBasePathConfigRootKey']                                            = 'join-path $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "Certificates"'
  $global:configRootKeys['SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey']                       = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesBasePathConfigRootKey"]] "EncryptionPassPhraseFiles"'
  $global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']                                   = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesBasePathConfigRootKey"]] "EncryptedKeys"'
  $global:configRootKeys['SecureCertificatesCertificateRequestsPathConfigRootKey']                             = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesBasePathConfigRootKey"]] "CertificateRequests"'
  $global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']                                    = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesBasePathConfigRootKey"]] "Certificates"'
  $global:configRootKeys['SecureCertificatesDataEncryptionCertificatesPathConfigRootKey']                      = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesCertificatesPathConfigRootKey"]] "DECs"'
  # Use this if special purpose openSSL configuration files are needed
  $global:configRootKeys['SecureCertificatesOpenSSLConfigsPathConfigRootKey']                                  = 'join-path $global:settings[$global:configRootKeys["SecureCertificatesBasePathConfigRootKey"]] "CertificateRequestConfigs"'
  # Use this if obfuscation of file names is desired
  $global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']                              = 'CrossReference.txt'

  #  These define where a Certificate Authority (CA) keeps the records of the CSRs it is given, and a copy of each Certificate it creates and sign
  #$global:configRootKeys['SecureCertificatesSigningCertificatesPrivateKeysRelativePathConfigRootKey'] = "'PrivateKeys'"
  #$global:configRootKeys['SecureCertificatesSigningCertificatesNewCertificatesRelativePathConfigRootKey'] ="'NewCertificates'"
  $global:configRootKeys['SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey'] = 'CertificateIssuedDB.txt'
  #$global:configRootKeys['SecureCertificatesSigningCertificatesSerialNumberRelativePathConfigRootKey'] = '"CertificateSerialNumber.txt"'

  # These define the latter portion of certificate-related filename (used as the parameter -BaseFileName)
  $global:configRootKeys['SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey']                        = 'CAPassPhraseFile.txt'
  $global:configRootKeys['SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey']                   = 'CAEncryptedPrivateKey.pem'
  $global:configRootKeys['SecureCertificatesCACertificateBaseFileNameConfigRootKey']                           = 'CACertificate.crt'
  $global:configRootKeys['SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey']                 = 'SSLServerPassPhraseFile.txt'
  $global:configRootKeys['SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey']            = 'SSLServerEncryptedPrivateKey.pem'
  $global:configRootKeys['SecureCertificatesSSLServerCertificateRequestBaseFileNameConfigRootKey']             = 'SSLServerCertificateRequest.csr'
  $global:configRootKeys['SecureCertificatesSSLServerCertificateBaseFileNameConfigRootKey']                    = 'SSLServerCertificate.crt'
  $global:configRootKeys['SecureCertificatesCodeSigningPassPhraseFileBaseFileNameConfigRootKey']               = 'CodeSigningPassPhraseFile.txt'
  $global:configRootKeys['SecureCertificatesCodeSigningEncryptedPrivateKeyBaseFileNameConfigRootKey']          = 'CodeSigningEncryptedPrivateKey.pem'
  $global:configRootKeys['SecureCertificatesCodeSigningCertificateRequestBaseFileNameConfigRootKey']           = 'CodeSigningCertificateRequest.csr'
  $global:configRootKeys['SecureCertificatesCodeSigningCertificateBaseFileNameConfigRootKey']                  = 'CodeSigningCertificate.crt'


  # Related to SecretManagement
  #  In general, places where the files that are used to store Secret Vaults are found
  $global:configRootKeys['SecretVaultBaseDirectoryConfigRootKey']                                              = 'join-path $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "Vaults"'
  #  Realtive to the SecretVaultBasePath, the base directorys for the vault files, Encryption Key files, and Encrypted Password files
  $global:configRootKeys['SecretVaultDatabasesDirectoryConfigRootKey']                                         = 'join-path $global:settings[$global:configRootKeys["SecretVaultBaseDirectoryConfigRootKey"]] "VaultDatabases"'
  $global:configRootKeys['SecretVaultEncryptionKeysDirectoryConfigRootKey']                                    = 'join-path $global:settings[$global:configRootKeys["SecretVaultBaseDirectoryConfigRootKey"]] "EncryptionKeyFiles"'
  $global:configRootKeys['SecretVaultEncryptedPasswordsDirectoryConfigRootKey']                                = 'join-path $global:settings[$global:configRootKeys["SecretVaultBaseDirectoryConfigRootKey"]] "EncryptedPasswordFiles"'

  # Specific organization's Secret Vault information, for ATAP organization
  # TBD strucutre for multiple vaults
  # TBD move out of the  global_ settings and into an organization specific setting file

  # Secret Vault encryption key files and encrypted passwords fles (passwords to open the vaults)
  $global:configRootKeys['SecretVaultPathToKeePassDBConfigRootKey']                                            = 'Join-Path $global:settings[$global:configRootKeys["SecretVaultDatabasesDirectoryConfigRootKey"]] "Local.ATAP.Utilities.kdbx"'
  $global:configRootKeys['SecretVaultEncryptionKeyFilePathConfigRootKey']                                      = 'Join-Path $global:settings[$global:configRootKeys["SecretVaultEncryptionKeysDirectoryConfigRootKey"]] "SecretVaultTestingEncryption.key"'
  $global:configRootKeys['SecretVaultEncryptedPasswordFilePathConfigRootKey']                                  = 'Join-Path $global:settings[$global:configRootKeys["SecretVaultEncryptedPasswordsDirectoryConfigRootKey"]] "SecretVaultTestingEncryptedPassword.txt"'

  # The specific details of the Secret Vault module in use
  $global:configRootKeys['SecretVaultNameConfigRootKey']                                                      = 'ThisUsersSecretVault'
  $global:configRootKeys['SecretVaultModuleNameConfigRootKey']                                                = 'SecretManagement.Keepass'
  $global:configRootKeys['SecretVaultDescriptionConfigRootKey']                                               = 'Secrets stored in a secure vault'
  $global:configRootKeys['SecretVaultKeySizeIntConfigRootKey']                                                = '32'
  $global:configRootKeys['SecretVaultPasswordTimeoutConfigRootKey']                                           = '300'


  # Place to keep things for Disaster recovery
  # $global:ConfigRootKeys['DisasterRecoveryPathConfigRootKey']                                                  = 'Join-path $global:settings[$global:ConfigRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "DisasterRecovery"'
  # ToDo: figure out how to handle USB sticks and what if not plugged in
  $global:ConfigRootKeys['DisasterRecoveryBackupPathConfigRootKey']                                            = 'Join-path "C:" "DisasterRecovery"'
}

# If a global hash variable already exists, modify the global with the local information
# This supports the ability to have multiple files define these values
if ($global:SecurityAndSecretsSettings) {
  Write-PSFMessage -Level Debug -Message 'global:SecurityAndSecretsSettings are already defined '
  # Load the $global:SecurityAndSecretsSettings with the $Local:SecurityAndSecretsSettings
  $keys = $local_SecurityAndSecretsSettings.Keys
  foreach ($key in $keys ) {
    # ToDo error handling if one fails
    $global:SecurityAndSecretsSettings[$key] = $local_SecurityAndSecretsSettings[$key]
  }
}
else {
  Write-PSFMessage -Level Debug -Message 'global:SecurityAndSecretsSettings are NOT defined'
  $global:SecurityAndSecretsSettings = $local_SecurityAndSecretsSettings
}


