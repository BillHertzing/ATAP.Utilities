# ToDo comment based help
$global:configRootKeys = @{
  'ATAPUtilitiesVersionConfigRootKey'                                = 'ATAPUtilitiesVersion'
  'ENVIRONMENTConfigRootKey'                                         = 'Environment'
  'IsElevatedConfigRootKey'                                          = 'IsElevated'
  'CloudBasePathConfigRootKey'                                       = 'CloudBasePath'
  'DropboxBasePathConfigRootKey'                                     = 'DropboxBasePath'
  'GoogleDriveBasePathConfigRootKey'                                 = 'GoogleDriveBasePath'
  'DropboxAccessTokenConfigRootKey'                                  = 'DropboxAccessToken'
  'OneDriveBasePathConfigRootKey'                                    = 'OneDriveBasePath'
  'FastTempBasePathConfigRootKey'                                    = 'FAST_TEMP_BASE_PATH'
  'BigTempBasePathConfigRootKey'                                     = 'BIG_TEMP_BASE_PATH'
  'SecureTempBasePathConfigRootKey'                                  = 'SECURE_TEMP_BASE_PATH'
  'ErlangHomeDirConfigRootKey'                                       = 'ErlangHomeDir'
  'GIT_CONFIG_GLOBALConfigRootKey'                                   = 'GIT_CONFIG_GLOBAL'
  'GitExePathConfigRootKey'                                          = 'GitExePath'
  'JavaExePathConfigRootKey'                                         = 'JavaExePath'
  'JENKINS_URLConfigRootKey'                                         = 'JENKINS_URL'
  'JENKINS_USER_IDConfigRootKey'                                     = 'JENKINS_USER_ID'
  'JENKINS_API_TOKENConfigRootKey'                                   = 'JENKINS_API_TOKEN'
  'JenkinsNodeRolesConfigRootKey'                                    = 'JenkinsNodeRoles'
  'ChocolateyInstallDirConfigRootKey'                                = 'ChocolateyInstall'
  'ChocolateyBinDirConfigRootKey'                                    = 'ChocolateyBinDir'
  'ChocolateyLibDirConfigRootKey'                                    = 'ChocolateyLibDir'
  'GraphvizExePathConfigRootKey'                                     = 'GraphvizExePath'
  'PackageDropPathsConfigRootKey'                                    = 'PackageDropPaths'
  'WindowsDocumentationBuildConfigRootKey'                           = 'WindowsDocumentationBuild'
  'BuildImageFromPlantUMLConfigRootKey'                              = 'BuildImageFromPlantUMPowershellCmdlet'
  'WindowsCodeBuildConfigRootKey'                                    = 'WindowsCodeBuild'
  'WindowsUnitTestConfigRootKey'                                     = 'WindowsUnitTest'
  'MSBuildExePathConfigRootKey'                                      = 'MSBuildExePath'
  'xUnitConsoleTestRunnerPackageConfigRootKey'                       = 'xUnitConsoleTestRunnerPackage'
  'xUnitJenkinsPluginPackageConfigRootKey'                           = 'xUnitJenkinsPluginPackage'
  'DocFXExePathConfigRootKey'                                        = 'DocFXExePath'
  'DotnetExePathConfigRootKey'                                       = 'DotnetExePath'
  'PlantUMLJarPathConfigRootKey'                                     = 'PlantUMLJarPath'
  'PlantUmlClassDiagramGeneratorExePathConfigRootKey'                = 'PlantUmlClassDiagramGeneratorExePath'
  'BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'          = 'BuildImageFromPlantUMLPowershellCmdletName'
  'SQLServerPSModulePathsConfigRootKey'                              = 'SQLServerPSModulePaths'
  'SQLServerConnectionStringConfigRootKey'                           = 'SQLServerConnectionString'
  'WindowsUnitTestParameterListConfigRootKey'                        = 'WindowsUnitTestParameterList'
  'WindowsUnitTestParameterPathConfigRootKey'                        = 'WindowsUnitTestParameterPath'
  'PSModulePathConfigRootKey'                                        = 'PSModulePath'
  'FLYWAY_PASSWORDConfigRootKey'                                     = 'FLYWAY_PASSWORD'
  'FLYWAY_USERConfigRootKey'                                         = 'FLYWAY_USER'
  'FLYWAY_LOCATIONSConfigRootKey'                                    = 'FLYWAY_LOCATIONS'
  'FLYWAY_URLConfigRootKey'                                          = 'FLYWAY_URL'
  'FP__projectNameConfigRootKey'                                     = 'FP__projectName'
  'FP__projectDescriptionConfigRootKey'                              = 'FP__projectDescription'
  'CommonJarsBasePathConfigRootKey'                                  = 'CommonJarsBasePath'

  'FileSystemDropsBasePathConfigRootKey'                             = 'FileSystemDropsBasePath'
  'WebServerDropsBaseURLConfigRootKey'                               = 'WebServerDropsBaseURL'


  # Where all things Security and Secrets related are stored

  # OpenSSL Environment variables
  'OPENSSL_HOMEConfigRootKey'                                        = 'OPENSSL_HOME'
  'OPENSSL_CONFConfigRootKey'                                        = 'OPENSSL_CONF'
  'RANDFILEConfigRootKey'                                            = 'RANDFILE'

# Subdirectory where all files security related are kept
  'SECURE_CLOUD_BASE_PATHConfigRootKey'                              = 'SECURE_CLOUD_BASE_PATH'
  # Related to Certificate creation and storage
  'CertificateSecurityBasePathConfigRootKey'                         = 'CertificateSecurityBasePath'
  'CertificateSecurityEncryptionKeyPassPhraseFilesPathConfigRootKey' = 'CertificateSecurityEncryptionKeyPassPhraseFilesPath'
  'CertificateSecurityEncryptedKeysPathConfigRootKey'                = 'CertificateSecurityEncryptedKeysPath'
  'CertificateSecurityCertificateRequestConfigsPathConfigRootKey'    = 'CertificateSecurityCertificateRequestConfigsPath'
  'CertificateSecurityCertificateRequestsPathConfigRootKey'          = 'CertificateSecurityCertificateRequestsPath'
  'CertificateSecurityCertificatesPathConfigRootKey'                 = 'CertificateSecurityCertificatesPath'

  'CertificateSecurityCertificateSerialNumberPathConfigRootKey'      = 'CertificateSecurityCertificateSerialNumberPath'
  'CertificateSecurityCertificateIssuedDBPathConfigRootKey'          = 'CertificateSecurityCertificateIssuedDBPath'
  'CertificateSecurityCrossReferenceDNFileConfigRootKey'             = 'CertificateSecurityCrossReferenceDNFile'
  'CertificateSecurityDNFilePathReplacementPatternConfigRootKey'     = 'CertificateSecurityDNFilePathReplacementPattern'


  # SecretsManagement
  'SecureCloudVaultPathConfigRootKey'                                = 'SecureCloudVaultPath'
  'SecureCloudEncryptedSecretsConfigRootKey'                         = 'SecureCloudEncryptedSecretsPath'
  'EncryptedMasterPasswordsPathConfigRootKey'                        = 'EncryptedMasterPasswordsPath'
  'ATAPUtilitiesMasterPasswordsPathConfigRootKey'                    = 'ATAPUtilitiesMasterPasswordsPath'
  'SecretManagementVaultsPathConfigRootKey'                          = 'SecretManagementVaultsPath'
  'DataEncryptionCertificatesPathConfigRootKey'                      = 'DataEncryptionCertificatesPath'


  'SecretVaultExtensionModuleNameConfigRootKey'                      = 'SecretExtensionVaultModuleName'
  'SecretVaultNameConfigRootKey'                                     = 'SecretVaultName'
  'SecretVaultDescriptionConfigRootKey'                              = 'SecretVaultDescription'
  'SecretVaultKeySizeIntConfigRootKey'                               = 'SecretVaultKeySizeInt'
  'SecretVaultPasswordTimeoutConfigRootKey'                          = 'SecretVaultPasswordTimeout'
  'SecretVaultEncryptedPasswordFilePathConfigRootKey'                = 'SecretVaultEncryptedPasswordFilePath'
  'SecretVaultKeyFilePathConfigRootKey'                              = 'SecretVaultKeyFilePath'
  'SecretVaultPathToKeePassDBConfigRootKey'                          = 'SecretVaultPathToKeePassDB'

  # Locations for things that are needed in case of disaster
  'DisasterRecoveryPathConfigRootKey'                                = 'DisasterRecoveryPath'
  'DisasterRecoveryBackupPathConfigRootKey'                          = 'DisasterRecoveryBackupPath'
}

$global:CanaconicalMachineRoleStrings = @{
  # strings that describe the Machine Roles
  'DeveloperComputerRole'         = 'DeveloperComputer'
  'DocumentationComputerRole'     = 'DocumentationComputer'
  'TestingComputerRole'           = 'TestingComputer'
  'CICDComputerRole'              = 'CICDComputer'
  'DocFXComputerRole'             = 'DocFXComputer'
  'WebServerComputerRole'         = 'WebServerComputer'
  'JenkinsControllerComputerRole' = 'JenkinsControllerComputer'
  'JenkinsAgentComputerRole'      = 'JenkinsAgentComputer'
  'MSSQLServerComputerRole'       = 'MSSQLServerComputer'
  'PlantUMLComputerRole'          = 'PlantUMLComputer'
  'CertificateServerComputerRole' = 'CertificateServerComputer'
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
  $global:CanaconicalMachineRoleStrings['DeveloperComputerRole']         = @{DependsOn = $null }
  $global:CanaconicalMachineRoleStrings['DocumentationComputerRole']     = @{DependsOn = @($global:CanaconicalMachineRoleStrings['DocFXComputerRole'], $global:CanaconicalMachineRoleStrings['PlantUMLComputerRole']) }
  $global:CanaconicalMachineRoleStrings['TestingComputerRole']           = @{DependsOn = $null }
  $global:CanaconicalMachineRoleStrings['WebServerComputerRole']         = @{DependsOn = $null }
  $global:CanaconicalMachineRoleStrings['CertificateServerComputerRole'] = @{DependsOn = $null }
  $global:CanaconicalMachineRoleStrings['CICDComputerRole']              = @{DependsOn = $null }
  $global:CanaconicalMachineRoleStrings['JenkinsControllerComputerRole'] = @{DependsOn = $null }
  $global:CanaconicalMachineRoleStrings['JenkinsAgentComputerRole']      = @{DependsOn = $null }
  $global:CanaconicalMachineRoleStrings['MSSQLServerComputerRole']       = @{DependsOn = $null }
  $global:CanaconicalMachineRoleStrings['DocFXComputerRole']             = @{DependsOn = $null }
  $global:CanaconicalMachineRoleStrings['PlantUMLComputerRole']          = @{DependsOn = $null }
}

