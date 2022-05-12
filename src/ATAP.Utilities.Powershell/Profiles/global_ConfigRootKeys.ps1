# ToDo comment based help
$global:configRootKeys = @{
  'ATAPUtilitiesVersionConfigRootKey' = 'ATAPUtilitiesVersion'
  'ENVIRONMENTConfigRootKey' = 'Environment'
  'IsElevatedConfigRootKey' = 'IsElevated'
  'CloudBasePathConfigRootKey' = 'CloudBasePath'
  'DropboxBasePathConfigRootKey' = 'DropboxBasePath'
  'GoogleDriveBasePathConfigRootKey' = 'GoogleDriveBasePath'
  'DropboxAccessTokenConfigRootKey' = 'DropboxAccessToken'
  'OneDriveBasePathConfigRootKey' = 'OneDriveBasePath'
  'FastTempBasePathConfigRootKey' = 'FAST_TEMP_BASE_PATH'
  'BigTempBasePathConfigRootKey' = 'BIG_TEMP_BASE_PATH'
  'SecureTempBasePathConfigRootKey' = 'SECURE_TEMP_BASE_PATH'
  'ErlangHomeDirConfigRootKey' = 'ErlangHomeDir'
  'GIT_CONFIG_GLOBALConfigRootKey' = 'GIT_CONFIG_GLOBAL'
  'GitExePathConfigRootKey' = 'GitExePath'
  'JavaExePathConfigRootKey' = 'JavaExePath'
  # Jenkins CI/CD confguration keys
  'JenkinsNodeRolesConfigRootKey' = 'JenkinsNodeRoles'
  # Jenkins Environment Variables
  # JENKINS_HOME applies onbly to jenkins Controller nodes
  'JENKINS_HOMEConfigRootKey' = 'JENKINS_HOME'
  # These Jenkins Environment Variables are used to access a Jenkins Controller and Authenticate
  'JENKINS_URLConfigRootKey' = 'JENKINS_URL'
  'JENKINS_USER_IDConfigRootKey' = 'JENKINS_USER_ID'
  'JENKINS_API_TOKENConfigRootKey' = 'JENKINS_API_TOKEN'
  'ChocolateyInstallDirConfigRootKey' = 'ChocolateyInstall'
  'ChocolateyBinDirConfigRootKey' = 'ChocolateyBinDir'
  'ChocolateyLibDirConfigRootKey' = 'ChocolateyLibDir'
  'GraphvizExePathConfigRootKey' = 'GraphvizExePath'
  'PackageDropPathsConfigRootKey' = 'PackageDropPaths'
  'WindowsDocumentationBuildConfigRootKey' = 'WindowsDocumentationBuild'
  'BuildImageFromPlantUMLConfigRootKey' = 'BuildImageFromPlantUMPowershellCmdlet'
  'WindowsCodeBuildConfigRootKey' = 'WindowsCodeBuild'
  'WindowsUnitTestConfigRootKey' = 'WindowsUnitTest'
  'MSBuildExePathConfigRootKey' = 'MSBuildExePath'
  'xUnitConsoleTestRunnerPackageConfigRootKey' = 'xUnitConsoleTestRunnerPackage'
  'xUnitJenkinsPluginPackageConfigRootKey' = 'xUnitJenkinsPluginPackage'
  'DocFXExePathConfigRootKey' = 'DocFXExePath'
  'DotnetExePathConfigRootKey' = 'DotnetExePath'
  'PlantUMLJarPathConfigRootKey' = 'PlantUMLJarPath'
  'PlantUmlClassDiagramGeneratorExePathConfigRootKey' = 'PlantUmlClassDiagramGeneratorExePath'
  'BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey' = 'BuildImageFromPlantUMLPowershellCmdletName'
  'SQLServerPSModulePathsConfigRootKey' = 'SQLServerPSModulePaths'
  'SQLServerConnectionStringConfigRootKey' = 'SQLServerConnectionString'
  'WindowsUnitTestParameterListConfigRootKey' = 'WindowsUnitTestParameterList'
  'WindowsUnitTestParameterPathConfigRootKey' = 'WindowsUnitTestParameterPath'
  'PSModulePathConfigRootKey' = 'PSModulePath'
  'FLYWAY_PASSWORDConfigRootKey' = 'FLYWAY_PASSWORD'
  'FLYWAY_USERConfigRootKey' = 'FLYWAY_USER'
  'FLYWAY_LOCATIONSConfigRootKey' = 'FLYWAY_LOCATIONS'
  'FLYWAY_URLConfigRootKey' = 'FLYWAY_URL'
  'FP__projectNameConfigRootKey' = 'FP__projectName'
  'FP__projectDescriptionConfigRootKey' = 'FP__projectDescription'
  'CommonJarsBasePathConfigRootKey' = 'CommonJarsBasePath'

  'FileSystemDropsBasePathConfigRootKey' = 'FileSystemDropsBasePath'
  'WebServerDropsBaseURLConfigRootKey' = 'WebServerDropsBaseURL'


  # Where all things Security and Secrets related are stored
  'SECURE_CLOUD_BASE_PATHConfigRootKey' = 'SECURE_CLOUD_BASE_PATH'

  # OpenSSL Environment variables
  'OPENSSL_HOMEConfigRootKey' = 'OPENSSL_HOME'
  'OPENSSL_CONFConfigRootKey' = 'OPENSSL_CONF'
  'RANDFILEConfigRootKey' = 'RANDFILE'

  # Subdirectory where all files security related are kept
  # Related to PKI Certificate creation and storage
  'SecureCertificatesPathConfigRootKey' = 'CertificateSecurityBasePath'
  'SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey' = 'CertificateSecurityEncryptionKeyPassPhraseFilesPath'
  'SecureCertificatesEncryptedKeysPathConfigRootKey' = 'CertificateSecurityEncryptedKeysPath'
  'SecureCertificatesCertificateRequestsPathConfigRootKey' = 'CertificateSecurityCertificateRequestsPath'
  'SecureCertificatesCertificatesPathConfigRootKey' = 'CertificateSecurityCertificatesPath'
  # Use this if special purpose openSSL configuration files are needed
  'SecureCertificatesOpenSSLConfigsPathConfigRootKey' = 'SecureCertificatesOpenSSLConfigsPath'
  # Use this if obfuscation of file names is desired
  'SecureCertificatesCrossReferenceFilenameConfigRootKey' = 'CertificateSecurityCrossReferenceDNFile'

  #  These define where a Certificte Authority (CA) keeps the records of the CSRs it is given, and a copy of each Certificate it creates and signs
  'SecureCertificatesSigningCertificatesPathConfigRootKey' = 'CertificateSecuritySigningCertificatesPath'
  #'SecureCertificatesSigningCertificatesPrivateKeysRelativePathConfigRootKey' = 'SecureCertificatesSigningCertificatesPrivateKeysRelativePath'
  #'SecureCertificatesSigningCertificatesNewCertificatesRelativePathConfigRootKey' ='SecureCertificatesSigningCertificatesNewCertificatesRelativePath'
  'SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey' ='SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePath'
  #'SecureCertificatesSigningCertificatesSerialNumberRelativePathConfigRootKey' ='SecureCertificatesSigningCertificatesSerialNumberRelativePath'

  # These define the latter portion of certificate-related filename (used as the parameter -BaseFileName)
  'SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey' = 'SecureCertificatesCAPassPhraseFileBaseFileName'
  'SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey' = 'SecureCertificatesCAEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesCACertificateBaseFileNameConfigRootKey' = 'SecureCertificatesCACertificateBaseFileName'
  'SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey' = 'SecureCertificatesSSLServerPassPhraseFileBaseFileName'
  'SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey' = 'SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesSSLServerCertificateRequestBaseFileNameConfigRootKey' = 'SecureCertificatesSSLServerCertificateRequestBaseFileName'
  'SecureCertificatesSSLServerCertificateBaseFileNameConfigRootKey' = 'SecureCertificatesSSLServerCertificateBaseFileName'

  # SecretsManagement
  'SecureCloudVaultPathConfigRootKey' = 'SecureCloudVaultPath'
  'SecureCloudEncryptedSecretsConfigRootKey' = 'SecureCloudEncryptedSecretsPath'
  'EncryptedMasterPasswordsPathConfigRootKey' = 'EncryptedMasterPasswordsPath'
  'ATAPUtilitiesMasterPasswordsPathConfigRootKey' = 'ATAPUtilitiesMasterPasswordsPath'
  'SecretManagementVaultsPathConfigRootKey' = 'SecretManagementVaultsPath'
  'DataEncryptionCertificatesPathConfigRootKey' = 'DataEncryptionCertificatesPath'


  'SecretVaultExtensionModuleNameConfigRootKey' = 'SecretExtensionVaultModuleName'
  'SecretVaultNameConfigRootKey' = 'SecretVaultName'
  'SecretVaultDescriptionConfigRootKey' = 'SecretVaultDescription'
  'SecretVaultKeySizeIntConfigRootKey' = 'SecretVaultKeySizeInt'
  'SecretVaultPasswordTimeoutConfigRootKey' = 'SecretVaultPasswordTimeout'
  'SecretVaultEncryptedPasswordFilePathConfigRootKey' = 'SecretVaultEncryptedPasswordFilePath'
  'SecretVaultKeyFilePathConfigRootKey' = 'SecretVaultKeyFilePath'
  'SecretVaultPathToKeePassDBConfigRootKey' = 'SecretVaultPathToKeePassDB'

  # Locations for things that are needed in case of disaster
  'DisasterRecoveryPathConfigRootKey' = 'DisasterRecoveryPath'
  'DisasterRecoveryBackupPathConfigRootKey' = 'DisasterRecoveryBackupPath'

  # Container (Machine, VM, Docker) Roles
  'DeveloperComputerRoleConfigRootKey'         = 'DeveloperComputer'
  'DocumentationComputerRoleConfigRootKey'     = 'DocumentationComputer'
  'TestingComputerRoleConfigRootKey'           = 'TestingComputer'
  'CICDComputerRoleConfigRootKey'              = 'CICDComputer'
  'DocFXComputerRoleConfigRootKey'             = 'DocFXComputer'
  'WebServerComputerRoleConfigRootKey'         = 'WebServerComputer'
  'JenkinsControllerComputerRoleConfigRootKey' = 'JenkinsControllerComputer'
  'JenkinsAgentComputerRoleConfigRootKey'      = 'JenkinsAgentComputer'
  'MSSQLServerComputerRoleConfigRootKey'       = 'MSSQLServerComputer'
  'PlantUMLComputerRoleConfigRootKey'          = 'PlantUMLComputer'
  'CertificateServerComputerRoleConfigRootKey' = 'CertificateServerComputer'
}



$global:CanaconicalUserRoleStrings = @{
  'SecurityAdministratorRole'              = 'SecurityAdministrator'
  'DeveloperRole'                          = 'Developer'
  'TesterRole'                             = 'Tester'
  'DocumenterRole'                         = 'Documenter'
  'MSSQLDatabaseaAdministratorRole'        = 'MSSQLDatabaseaAdministrator'
  'MySQLDatabaseaAdministratorRole'        = 'MySQLDatabaseaAdministrator'
  'SecurityAdministratorManagerRole'       = 'SecurityAdministratorManager'
  'DeveloperManagerRole'                   = 'DeveloperManager'
  'TesterManagerRole'                      = 'TesterManager'
  'DocumenterManagerRole'                  = 'DocumenterManager'
  'MSSQLDatabaseaAdministratorManagerRole' = 'MSSQLDatabaseaAdministratorManager'
  'MySQLDatabaseaAdministratorManagerRole' = 'MySQLDatabaseaAdministratorManager'
  'ProductionReleaseManagerRole'           = 'ProductionReleaseManager'
}

$global:CanaconicalUserRoles = @{
  $global:CanaconicalUserRoleStrings['SecurityAdministratorRole']              = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['SecurityAdministratorManagerRole']       = @{DependsOn = $global:CanaconicalUserRoleStrings['SecurityAdministratorRole'] }
  $global:CanaconicalUserRoleStrings['DeveloperRole']                          = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['TesterRole']                             = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['DocumenterRole']                         = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['MSSQLDatabaseaAdministratorRole']        = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['MySQLDatabaseaAdministratorRole']        = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['DeveloperManagerRole']                   = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['TesterManagerRole']                      = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['DocumenterManagerRole']                  = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['MSSQLDatabaseaAdministratorManagerRole'] = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['MySQLDatabaseaAdministratorManagerRole'] = @{DependsOn = $null }
  $global:CanaconicalUserRoleStrings['ProductionReleaseManagerRole']           = @{DependsOn = $null }
}

$global:CanaconicalMachineRoles = @{
  $global:configRootKeys['DeveloperComputerRoleConfigRootKey']         = @{DependsOn = $null }
  $global:configRootKeys['DocumentationComputerRoleConfigRootKey']     = @{DependsOn = @($global:configRootKeys['DocFXComputerRoleConfigRootKey'], $global:configRootKeys['PlantUMLComputerRoleConfigRootKey']) }
  $global:configRootKeys['TestingComputerRoleConfigRootKey']           = @{DependsOn = $null }
  $global:configRootKeys['WebServerComputerRoleConfigRootKey']         = @{DependsOn = $null }
  $global:configRootKeys['CertificateServerComputerRoleConfigRootKey'] = @{DependsOn = $null }
  $global:configRootKeys['CICDComputerRoleConfigRootKey']              = @{DependsOn = $null }
  $global:configRootKeys['JenkinsControllerComputerRoleConfigRootKey'] = @{DependsOn = $null }
  $global:configRootKeys['JenkinsAgentComputerRoleConfigRootKey']      = @{DependsOn = $null }
  $global:configRootKeys['MSSQLServerComputerRoleConfigRootKey']       = @{DependsOn = $null }
  $global:configRootKeys['DocFXComputerRoleConfigRootKey']             = @{DependsOn = $null }
  $global:configRootKeys['PlantUMLComputerRoleConfigRootKey']          = @{DependsOn = $null }
}

