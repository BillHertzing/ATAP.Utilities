# ToDo comment based help
$global:configRootKeys = @{
  'ATAPUtilitiesVersionConfigRootKey'                                                      = 'ATAPUtilitiesVersion'
  'ENVIRONMENTConfigRootKey'                                                               = 'Environment'
  'IsElevatedConfigRootKey'                                                                = 'IsElevated'
  'CloudBasePathConfigRootKey'                                                             = 'CloudBasePath'
  'DropboxBasePathConfigRootKey'                                                           = 'DropboxBasePath'
  'GoogleDriveBasePathConfigRootKey'                                                       = 'GoogleDriveBasePath'
  'DropboxAccessTokenConfigRootKey'                                                        = 'DropboxAccessToken'
  'OneDriveBasePathConfigRootKey'                                                          = 'OneDriveBasePath'
  'FastTempBasePathConfigRootKey'                                                          = 'FAST_TEMP_BASE_PATH'
  'BigTempBasePathConfigRootKey'                                                           = 'BIG_TEMP_BASE_PATH'
  'SecureTempBasePathConfigRootKey'                                                        = 'SECURE_TEMP_BASE_PATH'
  'ErlangHomeDirConfigRootKey'                                                             = 'ErlangHomeDir'
  'GIT_CONFIG_GLOBALConfigRootKey'                                                         = 'GIT_CONFIG_GLOBAL'
  'GitExePathConfigRootKey'                                                                = 'GitExePath'
  'JavaExePathConfigRootKey'                                                               = 'JavaExePath'
  # Jenkins CI/CD confguration keys
  'JenkinsNodeRolesConfigRootKey'                                                          = 'JenkinsNodeRoles'
  # Jenkins Environment Variables
  # JENKINS_HOME applies onbly to jenkins Controller nodes
  'JENKINS_HOMEConfigRootKey'                                                              = 'JENKINS_HOME'
  # These Jenkins Environment Variables are used to access a Jenkins Controller and Authenticate
  'JENKINS_URLConfigRootKey'                                                               = 'JENKINS_URL'
  'JENKINS_USER_IDConfigRootKey'                                                           = 'JENKINS_USER_ID'
  'JENKINS_API_TOKENConfigRootKey'                                                         = 'JENKINS_API_TOKEN'
  'ChocolateyInstallDirConfigRootKey'                                                      = 'ChocolateyInstall'
  'ChocolateyBinDirConfigRootKey'                                                          = 'ChocolateyBinDir'
  'ChocolateyLibDirConfigRootKey'                                                          = 'ChocolateyLibDir'
  'GraphvizExePathConfigRootKey'                                                           = 'GraphvizExePath'
  'PackageDropPathsConfigRootKey'                                                          = 'PackageDropPaths'
  'BuildImageFromPlantUMLConfigRootKey'                                                    = 'BuildImageFromPlantUMPowershellCmdlet'
  'MSBuildExePathConfigRootKey'                                                            = 'MSBuildExePath'
  'xUnitConsoleTestRunnerPackageConfigRootKey'                                             = 'xUnitConsoleTestRunnerPackage'
  'xUnitJenkinsPluginPackageConfigRootKey'                                                 = 'xUnitJenkinsPluginPackage'
  'DocFXExePathConfigRootKey'                                                              = 'DocFXExePath'
  'DotnetExePathConfigRootKey'                                                             = 'DotnetExePath'
  'PlantUMLJarPathConfigRootKey'                                                           = 'PlantUMLJarPath'
  'PlantUmlClassDiagramGeneratorExePathConfigRootKey'                                      = 'PlantUmlClassDiagramGeneratorExePath'
  'BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'                                = 'BuildImageFromPlantUMLPowershellCmdletName'
  'SQLServerPSModulePathsConfigRootKey'                                                    = 'SQLServerPSModulePaths'
  'SQLServerConnectionStringConfigRootKey'                                                 = 'SQLServerConnectionString'
  'WindowsUnitTestParameterListConfigRootKey'                                              = 'WindowsUnitTestParameterList'
  'WindowsUnitTestParameterPathConfigRootKey'                                              = 'WindowsUnitTestParameterPath'
  'PSModulePathConfigRootKey'                                                              = 'PSModulePath'
  'FLYWAY_PASSWORDConfigRootKey'                                                           = 'FLYWAY_PASSWORD'
  'FLYWAY_USERConfigRootKey'                                                               = 'FLYWAY_USER'
  'FLYWAY_LOCATIONSConfigRootKey'                                                          = 'FLYWAY_LOCATIONS'
  'FLYWAY_URLConfigRootKey'                                                                = 'FLYWAY_URL'
  'FP__projectNameConfigRootKey'                                                           = 'FP__projectName'
  'FP__projectDescriptionConfigRootKey'                                                    = 'FP__projectDescription'
  'CommonJarsBasePathConfigRootKey'                                                        = 'CommonJarsBasePath'

   # Computer roles (used in the JenkinsNodeRoles)
  'WindowsCodeBuildConfigRootKey'                                                          = 'WindowsCodeBuild'
  'WindowsUnitTestConfigRootKey'                                                           = 'WindowsUnitTest'
  'WindowsIntegrationTestConfigRootKey'                                                    = 'WindowIntegrationTest'
  'WindowsDocumentationBuildConfigRootKey'                                                 = 'WindowsDocumentationBuild'

  # The subdirectory name under a repository root dir where files generated by the developer build and CI/CD process build are placed
  'GeneratedRelativePathConfigRootKey'                                                     = 'GeneratedSubdirectory'
  # the subdirectory name under the GeneratedRelativePath where the Powershell Module files are placed
  'GeneratedPowershellModuleConfigRootKey'                                                 = 'PowerShellModuleSubdirectory'
  # the subdirectory name under the GeneratedPowershellModules where the Powershell Module files for the Powershell Gallery are placed
  'GeneratedPowershellGalleryPackageConfigRootKey'                                         = 'PowershellGalleryPackageSubdirectory'
  # the subdirectory name under the GeneratedPowershellModules where the Powershell Module files for the Nuget.org server are placed
  'GeneratedPowershellNuGetPackageConfigRootKey'                                           = 'NuGetPackageSubdirectory'
  # the subdirectory name under the GeneratedPowershellModules where the Powershell Module files for the Chocolatey server are placed
  'GeneratedPowershellChocolateyPackageConfigRootKey'                                      = 'ChocolateyPackageSubdirectory'

  # The subdirectory name under a repository root where test results generated by the developer build and CI/CD process build are placed
  'GeneratedTestResultsPathConfigRootKey'                                                  = 'TestResultsSubdirectory'
  # The subdirectory name under a repository root where Unit test results generated by the developer build and CI/CD process build are placed
  'GeneratedUnitTestResultsPathConfigRootKey'                                              = 'UnitTestSubdirectory'
  # The subdirectory name under a repository root where Integration test results generated by the developer build and CI/CD process build are placed
  'GeneratedIntegrationTestResultsPathConfigRootKey'                                       = 'IntegrationTestSubdirectory'
  # The subdirectory name under a repository root where Integration test results generated by the developer build and CI/CD process build are placed
  'GeneratedTestCoverageResultsPathConfigRootKey'                                          = 'TestCoverageSubdirectory'

  # The subdirectory name under a repository root where documentation generated by the developer build and CI/CD process build are placed
  'GeneratedDocumentationDestinationPathConfigRootKey'                                     = 'DocumentationSubdirectory'
  # The subdirectory name under a repository root where static site documentation generated by the developer build and CI/CD process build are placed
  'GeneratedStaticSiteDocumentationDestinationPathConfigRootKey'                           = 'StaticSiteSubdirectory'

  # Packaging, Deploying, Delivering, Updating
  # The repository names by which each of the various repositories for Powershell packages are known
  # The name of the repository for Development Packages that are in PowershellGallery format and stored on the local filesystem
  'RepositoryNamePowershellGalleryFilesystemDevelopmentPackageConfigRootKey'               = 'RepositoryNamePowershellGalleryFilesystemDevelopmentPackage'
  'RepositoryNamePowershellGalleryFilesystemQualityAssurancePackageConfigRootKey'          = 'RepositoryNamePowershellGalleryFilesystemQualityAssurancePackage'
  'RepositoryNamePowershellGalleryFilesystemProductionPackageConfigRootKey'                = 'RepositoryNamePowershellGalleryFilesystemProductionPackage'
  'RepositoryNamePowershellGalleryWebServerTestDevelopmentPackageConfigRootKey'            = 'RepositoryNamePowershellGalleryWebServerTestDevelopmentPackage'
  'RepositoryNamePowershellGalleryWebServerTestQualityAssurancePackageConfigRootKey'       = 'RepositoryNamePowershellGalleryWebServerTestQualityAssurancePackage'
  'RepositoryNamePowershellGalleryWebServerTestProductionPackageConfigRootKey'             = 'RepositoryNamePowershellGalleryWebServerTestProductionPackage'
  'RepositoryNamePowershellGalleryWebServerProductionDevelopmentPackageConfigRootKey'      = 'RepositoryNamePowershellGalleryWebServerProductionDevelopmentPackage'
  'RepositoryNamePowershellGalleryWebServerProductionQualityAssurancePackageConfigRootKey' = 'RepositoryNamePowershellGalleryWebServerProductionQualityAssurancePackage'
  'RepositoryNamePowershellGalleryWebServerProductionProductionPackageConfigRootKey'       = 'RepositoryNamePowershellGalleryWebServerProductionProductionPackage'

  # the toplevel network resource name where the Powershell Package files for the filesystem implementation of the package providers (PowershellGallery, Nuget, and chocolatey)
  'CurrentFileSystemNetworkPackageDropLocationsConfigRootKey'                              = 'CurrentFileSystemNetworkPackageDropLocations' # 'utat021' # Network Configuration as Code, an awareness that this is a per-organization volitile variable
  # the toplevel network resource name where the Powershell Package files for the filesystem implementation of the package providers (PowershellGallery, Nuget, and chocolatey)
  'CurrentFileSystemNetworkPackageDropLocationBasePathConfigRootKey'                       = 'CurrentFileSystemNetworkPackageDropLocationBasePath' # 'utat021' # Network Configuration as Code, an awareness that this is a per-organization volitile variable
  'CurrentLocalPSGalleryWebServerPackageDropLocationBasePathConfigRootKey'                 = 'CurrentLocalPSGalleryWebServerPackageDropLocationBasePath'
  'CurrentLocalNugetWebServerPackageDropLocationBasePathConfigRootKey'                     = 'CurrentLocalNugetWebServerPackageDropLocationBasePath'
  'CurrentLocalChocolateyServerPackageDropLocationBasePathConfigRootKey'                   = 'CurrentLocalChocolateyServerPackageDropLocationBasePath'
  'PublicPSGalleryWebServerPackageDropLocationBasePathConfigRootKey'                       = 'PublicPSGalleryWebServerPackageDropLocationBasePath'
  'PublicNugetWebServerPackageDropLocationBasePathConfigRootKey'                           = 'PublicNugetWebServerPackageDropLocationBasePath'
  'PublicChocolateyServerPackageDropLocationBasePathConfigRootKey'                         = 'PublicChocolateyServerPackageDropLocationBasePath'
  'PackageRepositoriesCollectionConfigRootKey'                                             = 'PackageRepositoriesCollection'



  # Where all things Security and Secrets related are stored
  'SECURE_CLOUD_BASE_PATHConfigRootKey'                                                    = 'SECURE_CLOUD_BASE_PATH'

  # OpenSSL Environment variables
  'OPENSSL_HOMEConfigRootKey'                                                              = 'OPENSSL_HOME'
  'OPENSSL_CONFConfigRootKey'                                                              = 'OPENSSL_CONF'
  'RANDFILEConfigRootKey'                                                                  = 'RANDFILE'

  # Subdirectory where all files security related are kept
  # Related to PKI Certificate creation and storage
  'SecureCertificatesBasePathConfigRootKey'                                                = 'SecureCertificatesBasePath'
  'SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey'                           = 'SecureCertificatesEncryptionKeyPassPhraseFilesPath'
  'SecureCertificatesEncryptedKeysPathConfigRootKey'                                       = 'SecureCertificatesEncryptedKeysPath'
  'SecureCertificatesCertificateRequestsPathConfigRootKey'                                 = 'SecureCertificatesCertificateRequestsPath'
  'SecureCertificatesCertificatesPathConfigRootKey'                                        = 'SecureCertificatesCertificatesPath'
  'SecureCertificatesDataEncryptionCertificatesPathConfigRootKey'                          = 'SecureCertificatesDataEncryptionCertificatesPath'
  # Use this if special purpose openSSL configuration files are needed
  'SecureCertificatesOpenSSLConfigsPathConfigRootKey'                                      = 'SecureCertificatesOpenSSLConfigsPath'
  # Use this if obfuscation of file names is desired
  'SecureCertificatesCrossReferenceFilenameConfigRootKey'                                  = 'SecureCertificatesCrossReferenceDNFile'

  #  These define where a Certificte Authority (CA) keeps the records of the CSRs it is given, and a copy of each Certificate it creates and signs
  'SecureCertificatesSigningCertificatesPathConfigRootKey'                                 = 'SecureCertificatesSigningCertificatesPath'
  #'SecureCertificatesSigningCertificatesPrivateKeysRelativePathConfigRootKey' = 'SecureCertificatesSigningCertificatesPrivateKeysRelativePath'
  #'SecureCertificatesSigningCertificatesNewCertificatesRelativePathConfigRootKey' ='SecureCertificatesSigningCertificatesNewCertificatesRelativePath'
  'SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey'     = 'SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePath'
  #'SecureCertificatesSigningCertificatesSerialNumberRelativePathConfigRootKey' ='SecureCertificatesSigningCertificatesSerialNumberRelativePath'

  # These define the latter portion of certificate-related filename (used as the parameter -BaseFileName)
  'SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey'                            = 'SecureCertificatesCAPassPhraseFileBaseFileName'
  'SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey'                       = 'SecureCertificatesCAEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesCACertificateBaseFileNameConfigRootKey'                               = 'SecureCertificatesCACertificateBaseFileName'
  'SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey'                     = 'SecureCertificatesSSLServerPassPhraseFileBaseFileName'
  'SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey'                = 'SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesSSLServerCertificateRequestBaseFileNameConfigRootKey'                 = 'SecureCertificatesSSLServerCertificateRequestBaseFileName'
  'SecureCertificatesSSLServerCertificateBaseFileNameConfigRootKey'                        = 'SecureCertificatesSSLServerCertificateBaseFileName'
  'SecureCertificatesCodeSigningPassPhraseFileBaseFileNameConfigRootKey'                   = 'SecureCertificatesCodeSigningPassPhraseFileBaseFileName'
  'SecureCertificatesCodeSigningEncryptedPrivateKeyBaseFileNameConfigRootKey'              = 'SecureCertificatesCodeSigningEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesCodeSigningCertificateRequestBaseFileNameConfigRootKey'               = 'SecureCertificatesCodeSigningCertificateRequestBaseFileName'
  'SecureCertificatesCodeSigningCertificateBaseFileNameConfigRootKey'                      = 'SecureCertificatesCodeSigningCertificateBaseFileName'

  # SecretsManagement
  'SecureVaultBasePathConfigRootKey'                                                       = 'SecureVaultBasePath'
  'SecretVaultKeyFilePathConfigRootKey'                                                    = 'SecretVaultKeyFilePath'
  'SecretVaultEncryptedPasswordFilePathConfigRootKey'                                      = 'SecretVaultEncryptedPasswordFilePath'
  #'EncryptedMasterPasswordsPathConfigRootKey'                                          = 'EncryptedMasterPasswordsPath'
  # 'ATAPUtilitiesMasterPasswordsPathConfigRootKey'                                      = 'ATAPUtilitiesMasterPasswordsPath'
  'SecretVaultExtensionModuleNameConfigRootKey'                                            = 'SecretExtensionVaultModuleName'
  'SecretVaultNameConfigRootKey'                                                           = 'SecretVaultName'
  'SecretVaultDescriptionConfigRootKey'                                                    = 'SecretVaultDescription'
  'SecretVaultKeySizeIntConfigRootKey'                                                     = 'SecretVaultKeySizeInt'
  'SecretVaultPasswordTimeoutConfigRootKey'                                                = 'SecretVaultPasswordTimeout'
  'SecretVaultPathToKeePassDBConfigRootKey'                                                = 'SecretVaultPathToKeePassDB'

  # Locations for things that are needed in case of disaster
  'DisasterRecoveryPathConfigRootKey'                                                      = 'DisasterRecoveryPath'
  'DisasterRecoveryBackupPathConfigRootKey'                                                = 'DisasterRecoveryBackupPath'

  # Container (Machine, VM, Docker) Roles
  'DeveloperComputerRoleConfigRootKey'                                                     = 'DeveloperComputer'
  'DocumentationComputerRoleConfigRootKey'                                                 = 'DocumentationComputer'
  'TestingComputerRoleConfigRootKey'                                                       = 'TestingComputer'
  'CICDComputerRoleConfigRootKey'                                                          = 'CICDComputer'
  'DocFXComputerRoleConfigRootKey'                                                         = 'DocFXComputer'
  'WebServerComputerRoleConfigRootKey'                                                     = 'WebServerComputer'
  'JenkinsControllerComputerRoleConfigRootKey'                                             = 'JenkinsControllerComputer'
  'JenkinsAgentComputerRoleConfigRootKey'                                                  = 'JenkinsAgentComputer'
  'MSSQLServerComputerRoleConfigRootKey'                                                   = 'MSSQLServerComputer'
  'PlantUMLComputerRoleConfigRootKey'                                                      = 'PlantUMLComputer'
  'CertificateServerComputerRoleConfigRootKey'                                             = 'CertificateServerComputer'
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

