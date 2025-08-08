# ToDo comment based help
$global:configRootKeys = @{
  # IAC for Hosts having the C: drive as the systemdrive
  'SYSTEMDRIVEConfigRootKey'                                                                     = 'C:'
  'ProgramFilesConfigRootKey'                                                                    = 'ProgramFiles'
  'ProgramDataConfigRootKey'                                                                     = 'ProgramData'
  'ATAPUtilitiesVersionConfigRootKey'                                                            = 'ATAPUtilitiesVersion'
  'ENVIRONMENTConfigRootKey'                                                                     = 'Environment'
  'IsElevatedConfigRootKey'                                                                      = 'IsElevated'
  'CloudBasePathConfigRootKey'                                                                   = 'CloudBasePath'
  'GoogleDriveBasePathConfigRootKey'                                                             = 'GoogleDriveBasePath'
  # Dropbox settings
  'DropboxBasePathConfigRootKey'                                                                 = 'DropboxBasePath'
  'DropboxAccessTokenConfigRootKey'                                                              = 'DropboxAccessToken'
  # OneDrive Settings
  'OneDriveBasePathConfigRootKey'                                                                = 'OneDriveBasePath'
  'FastTempBasePathConfigRootKey'                                                                = 'FAST_TEMP_BASE_PATH'
  'BigTempBasePathConfigRootKey'                                                                 = 'BIG_TEMP_BASE_PATH'
  'SecureTempBasePathConfigRootKey'                                                              = 'SECURE_TEMP_BASE_PATH'
  'ChocolateyPackagesConfigRootKey'                                                              = 'ChocolateyPackages'
  # Ditto Clipboard Manager Settings
  'DittoDBPathConfigRootKey'                                                                     = 'DittoDBPath'
  # Erlang settings
  'ErlangHomeDirConfigRootKey'                                                                   = 'ErlangHomeDir'
  # GIT settings
  'GIT_CONFIG_GLOBALConfigRootKey'                                                               = 'GIT_CONFIG_GLOBAL'
  'GitExePathConfigRootKey'                                                                      = 'GitExePath'
  # JAVA interpreter executable settings
  'JavaInstallDirRelativeSubdirectoryConfigRootKey'                                              = 'JavaInstallDirRelativeSubdirectory'
  'JavaExePathConfigRootKey'                                                                     = 'JavaExePath'
  # Jenkins CI/CD configuration keys
  'JenkinsNodeRolesConfigRootKey'                                                                = 'JenkinsNodeRoles'
  # Jenkins Environment Variables
  # JENKINS_HOME applies only to jenkins Controller nodes
  'JENKINS_HOMEConfigRootKey'                                                                    = 'JENKINS_HOME'
  # These Jenkins Environment Variables are used to access a Jenkins Controller and Authenticate
  'JENKINS_URLConfigRootKey'                                                                     = 'JENKINS_URL'
  'JENKINS_USER_IDConfigRootKey'                                                                 = 'JENKINS_USER_ID'
  'JENKINS_API_TOKENConfigRootKey'                                                               = 'JENKINS_API_TOKEN'
  # ChatGPT settings
  'CHATGPT_URLConfigRootKey'                                                                     = 'CHATGPT_URL'
  'CHATGPT_USER_IDConfigRootKey'                                                                 = 'CHATGPT_USER_ID'
  'CHATGPT_API_TOKENConfigRootKey'                                                               = 'CHATGPT_API_TOKEN'

  'ChocolateyInstallDirConfigRootKey'                                                            = 'ChocolateyInstall'
  'ChocolateyBinDirConfigRootKey'                                                                = 'ChocolateyBinDir'
  'ChocolateyLibDirConfigRootKey'                                                                = 'ChocolateyLibDir'
  'ChocolateyCacheLocationConfigRootKey'                                                         = 'ChocolateyCacheLocation'
  'GraphvizExePathConfigRootKey'                                                                 = 'GraphvizExePath'
  'PackageDropPathsConfigRootKey'                                                                = 'PackageDropPaths'
  'BuildImageFromPlantUMLConfigRootKey'                                                          = 'BuildImageFromPlantUMPowershellCmdlet'
  'MSBuildExePathConfigRootKey'                                                                  = 'MSBuildExePath'
  'xUnitConsoleTestRunnerPackageConfigRootKey'                                                   = 'xUnitConsoleTestRunnerPackage'
  'xUnitJenkinsPluginPackageConfigRootKey'                                                       = 'xUnitJenkinsPluginPackage'
  'DocFXExePathConfigRootKey'                                                                    = 'DocFXExePath'
  'DotnetExePathConfigRootKey'                                                                   = 'DotnetExePath'
  'PlantUMLJarPathConfigRootKey'                                                                 = 'PlantUMLJarPath'
  'PlantUmlClassDiagramGeneratorExePathConfigRootKey'                                            = 'PlantUmlClassDiagramGeneratorExePath'
  'BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'                                      = 'BuildImageFromPlantUMLPowershellCmdletName'
  'SQLServerPSModulePathsConfigRootKey'                                                          = 'SQLServerPSModulePaths'
  'SQLServerConnectionStringConfigRootKey'                                                       = 'SQLServerConnectionString'
  'WindowsUnitTestParameterListConfigRootKey'                                                    = 'WindowsUnitTestParameterList'
  'WindowsUnitTestParameterPathConfigRootKey'                                                    = 'WindowsUnitTestParameterPath'
  'PSModulePathConfigRootKey'                                                                    = 'PSModulePath'
  'FLYWAY_PASSWORDConfigRootKey'                                                                 = 'FLYWAY_PASSWORD'
  'FLYWAY_USERConfigRootKey'                                                                     = 'FLYWAY_USER'
  'FLYWAY_LOCATIONSConfigRootKey'                                                                = 'FLYWAY_LOCATIONS'
  'FLYWAY_URLConfigRootKey'                                                                      = 'FLYWAY_URL'
  'FP__projectNameConfigRootKey'                                                                 = 'FP__projectName'
  'FP__projectDescriptionConfigRootKey'                                                          = 'FP__projectDescription'
  'CommonJarsBasePathConfigRootKey'                                                              = 'CommonJarsBasePath'

  #  # Allows Wireshark and other applications to capture the SSL Keys pre-negotiation, so HTTPS SSL traffic can be decrypted
  'SSLKEYLOGFILEConfigRootKey'                                                                   = 'SSLKEYLOGFILE'
  # Location of Python interpreter
  'PythonInterpretersBaseDirectoryConfigRootKey'                                                 = 'PythonInterpretersBaseDirectory'
  'PythonInterpretersInstallDirectoryConfigRootKey'                                              = 'PythonInterpretersInstallDirectory'
  'PythonExePathConfigRootKey'                                                                   = 'PythonExePath'

  # related to the Hydrus-Network application
  'HYDRUS_ACCESS_KEYConfigRootKey'                                                               = 'HydrusAccessKey'
  'HydrusAPIHostConfigRootKey'                                                                   = 'HydrusAPIServer'
  'HydrusAPISchemeConfigRootKey'                                                                 = 'HydrusAPIProtocol'
  'HydrusAPIPortConfigRootKey'                                                                   = 'HydrusAPIPort'

  # related to the Get-FileMetadata cmdlet
  'FileMetadataBlockSizeConfigRootKey'                                                           = 'FileMetadataBlockSize'
  'GetFileSignatureAsMetadataConfigRootKey'                                                      = 'GetFileSignatureAsMetadata'

  # Used by ansible
  'ansible_remote_tmpConfigRootKey'                                                              = 'ansible_remote_tmp'
  'ansible_become_userConfigRootKey'                                                             = 'ansible_become_user'
  'AnsibleAllowPrereleaseConfigRootKey'                                                          = 'AnsibleAllowPrelease'

  # CICDHosts configuration keys
  # Used by Jenkins Controller and agents
  'JenkinsControllerServiceAccountConfigRootKey'                                                 = 'JenkinsControllerServiceAccount'
  'JenkinsControllerServiceAccountPasswordKeyConfigRootKey'                                      = 'JenkinsControllerServiceAccountPasswordKey'
  'JenkinsControllerServiceAccountFullnameConfigRootKey'                                         = 'JenkinsControllerServiceAccountFullname'
  'JenkinsControllerServiceAccountDescriptionConfigRootKey'                                      = 'JenkinsControllerServiceAccountDescription'
  'JenkinsControllerServiceAccountUserHomeDirectoryConfigRootKey'                                = 'JenkinsControllerServiceAccountUserHomeDirectory'
  'JenkinsControllerServiceAccountPowershellDesktopProfileSourcePathConfigRootKey'               = 'JenkinsControllerServiceAccountPowershellDesktopProfileSourcePath'
  'JenkinsControllerServiceAccountPowershellCoreProfileSourcePathConfigRootKey'                  = 'JenkinsControllerServiceAccountPowershellCoreProfileSourcePath'
  'JenkinsAgentServiceAccountConfigRootKey'                                                      = 'JenkinsAgentServiceAccount'
  'JenkinsAgentServiceAccountPasswordKeyConfigRootKey'                                           = 'JenkinsAgentServiceAccountPasswordKey'
  'JenkinsAgentServiceAccountFullnameConfigRootKey'                                              = 'JenkinsAgentServiceAccountFullname'
  'JenkinsAgentServiceAccountDescriptionConfigRootKey'                                           = 'JenkinsAgentServiceAccountDescription'
  'JenkinsAgentServiceAccountUserHomeDirectoryConfigRootKey'                                     = 'JenkinsAgentServiceAccountUserHomeDirectory'
  'JenkinsAgentServiceAccountPowershellDesktopProfileSourcePathConfigRootKey'                    = 'JenkinsAgentServiceAccountPowershellDesktopProfileSourcePath'
  'JenkinsAgentServiceAccountPowershellCoreProfileSourcePathConfigRootKey'                       = 'JenkinsAgentServiceAccountPowershellCoreProfileSourcePath'

  # WinSW for Jenkins agent
  'WinSWPublicURLConfigRootKey'                                                                  = 'WinSWPublicURL'
  'WinSWInternalDestinationFilenameConfigRootKey'                                                = 'WinSWInternalDestinationFilename'
  'WinSWInternalDestinationBaseDirectoryConfigRootKey'                                           = 'WinSWInternalDestinationBaseDirectory'
  'WinSWInternalDestinationVersionConfigRootKey'                                                 = 'WinSWInternalDestinationVersion'
  'WinSWInternalDestinationDirectoryConfigRootKey'                                               = 'WinSWInternalDestinationDirectory'
  'WinSWInternalDestinationPathConfigRootKey'                                                    = 'WinSWInternalDestinationPath'

  # Computer roles (used in the JenkinsNodeRoles)
  'WindowsCodeBuildConfigRootKey'                                                                = 'WindowsCodeBuild'
  'WindowsUnitTestConfigRootKey'                                                                 = 'WindowsUnitTest'
  'WindowsIntegrationTestConfigRootKey'                                                          = 'WindowIntegrationTest'
  'WindowsDocumentationBuildConfigRootKey'                                                       = 'WindowsDocumentationBuild'

  # used by the jenkins role that creates a ProGetPackageRepositoryProvider
  'ProGetPackageRepositoryProviderServiceAccountConfigRootKey'                                   = 'ProGetPackageRepositoryProviderServiceAccount'
  'ProGetPackageRepositoryProviderServiceAccountPasswordKeyConfigRootKey'                        = 'ProGetPackageRepositoryProviderServiceAccountPasswordKey'
  'ProGetPackageRepositoryProviderServiceAccountFullnameConfigRootKey'                           = 'ProGetPackageRepositoryProviderServiceAccountFullname'
  'ProGetPackageRepositoryProviderServiceAccountDescriptionConfigRootKey'                        = 'ProGetPackageRepositoryProviderServiceAccountDescription'
  'ProGetPackageRepositoryProviderServiceAccountUserHomeDirectoryConfigRootKey'                  = 'ProGetPackageRepositoryProviderServiceAccountUserHomeDirectory'
  'ProGetPackageRepositoryProviderServiceAccountPowershellDesktopProfileSourcePathConfigRootKey' = 'ProGetPackageRepositoryProviderServiceAccountPowershellDesktopProfileSourcePath'
  'ProGetPackageRepositoryProviderServiceAccountPowershellCoreProfileSourcePathConfigRootKey'    = 'ProGetPackageRepositoryProviderServiceAccountPowershellCoreProfileSourcePath'

  # used by the ProGetPackageRepositoryProvider itself
  'ProGetServiceExePathConfigRootKey'                                                            = 'ProGetServiceExePath'
  'ProGetServiceConfigPathConfigRootKey'                                                         = 'ProGetServicePathPath'
  'ProGetAdminApiKeyConfigRootKey'                                                               = 'ProGetAdminApiKey'
  'ProGetAdminUriSchemeConfigRootKey'                                                            = 'ProGetAdminUriScheme'
  'ProGetAdminUriHostConfigRootKey'                                                              = 'ProGetAdminUriHost'
  'ProGetAdminUriPortConfigRootKey'                                                              = 'ProGetWebUIUriPort'

  # Used by the pgutil CLI program to access the ProgetPackageRepositoryProvider
  # This will also be an environment variable (currently being set in the personal profile)
  'PGUtilConfigPathConfigRootKey'                                                                = 'ProGetServicePathPath'
  # ToDo: refactor and remove the next line
  'PGUTIL_SOURCEConfigRootKey'                                                                   = 'PGUtilConfigPath'

  # Structure of the subdirectories generated during the process of building a Powershell Module for public distribution
  # The directory name where files used by the module/package creation and generated by the developer build and CI/CD process build are placed
  'TemporaryPowershellModulePackagingDirectoryConfigRootKey'                                     = 'TemporaryPowershellModulePackagingDirectory'
  # The directory name where module source files are placed by the module/package creation process during a developer build and CI/CD process build
  'TemporaryPowershellModulePackagingSourceDirectoryConfigRootKey'                               = 'TemporaryPowershellModulePackagingSourceDirectory'
  # The directory name where the generated intermediate package files are placed by the module/package creation process during a developer build and CI/CD process build
  'TemporaryPowershellModulePackagingIntermediateDirectoryConfigRootKey'                         = 'TemporaryPowershellModulePackagingIntermediateDirectory'
  # The directory name where the generated finished package files are placed by the module/package creation process during a developer build and CI/CD process build
  'TemporaryPowershellModulePackagingDistributionPackagesDirectoryConfigRootKey'                 = 'TemporaryPowershellModulePackagingDistributionPackagesDirectory'
  'GeneratedRelativePathConfigRootKey'                                                           = 'GeneratedSubdirectory'

  # The subdirectory name under a repository root where test results generated by the developer build and CI/CD process build are placed
  'GeneratedTestResultsPathConfigRootKey'                                                        = 'GeneratedTestResultsSubdirectory'
  # The subdirectory name under a repository root where Unit test results generated by the developer build and CI/CD process build are placed
  'GeneratedUnitTestResultsPathConfigRootKey'                                                    = 'GeneratedUnitTestResultsSubdirectory'
  # The subdirectory name under a repository root where Integration test results generated by the developer build and CI/CD process build are placed
  'GeneratedIntegrationTestResultsPathConfigRootKey'                                             = 'GeneratedIntegrationTestResultsSubdirectory'
  # The subdirectory name under a repository root where Integration test results generated by the developer build and CI/CD process build are placed
  'GeneratedTestCoverageResultsPathConfigRootKey'                                                = 'GeneratedTestCoverageREsultsSubdirectory'

  # The subdirectory name under a repository root where documentation generated by the developer build and CI/CD process build are placed
  'GeneratedDocumentationDestinationPathConfigRootKey'                                           = 'GeneratedDocumentationSubdirectory'
  # The subdirectory name under a repository root where static site documentation generated by the developer build and CI/CD process build are placed
  'GeneratedStaticSiteDocumentationDestinationPathConfigRootKey'                                 = 'GeneratedStaticSiteSubdirectory'

  # The collection that lists all powershell package repositories
  'PackageRepositoriesCollectionConfigRootKey'                                                   = 'PackageRepositoriesCollection'

  # Where all things Security and Secrets related are stored
  'SECURE_CLOUD_BASE_PATHConfigRootKey'                                                          = 'SECURE_CLOUD_BASE_PATH'

  # Powershell credentials for user/host pairs
  'SECURE_CLOUD_CREDENTIALS_PATHConfigRootKey'                                                   = 'SECURE_CLOUD_CREDENTIALS_PATH'

  # related to the Hashicorp Vault installation and operations
  'VAULT_ADDRConfigRootKey'                                                                      = 'VAULT_ADDR'
  'VAULT_TOKENConfigRootKey'                                                                     = 'VAULT_TOKEN'
  'VAULT_CACERTConfigRootKey'                                                                    = 'VAULT_CACERT'
  'VaultUnsealKeyConfigRootKey'                                                                  = 'VaultUnsealKey'
  'VaultRootTokenConfigRootKey'                                                                  = 'VaultRootToken'

  # OpenSSL Environment variables
  'OPENSSL_HOMEConfigRootKey'                                                                    = 'OPENSSL_HOME'
  'OPENSSL_CONFConfigRootKey'                                                                    = 'OPENSSL_CONF'
  'RANDFILEConfigRootKey'                                                                        = 'RANDFILE'

  # Subdirectory where all files security related are kept
  # Related to PKI Certificate creation and storage
  'SecureCertificatesBasePathConfigRootKey'                                                      = 'SecureCertificatesBasePath'
  'SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey'                                 = 'SecureCertificatesEncryptionKeyPassPhraseFilesPath'
  'SecureCertificatesEncryptedKeysPathConfigRootKey'                                             = 'SecureCertificatesEncryptedKeysPath'
  'SecureCertificatesCertificateRequestsPathConfigRootKey'                                       = 'SecureCertificatesCertificateRequestsPath'
  'SecureCertificatesCertificatesPathConfigRootKey'                                              = 'SecureCertificatesCertificatesPath'
  'SecureCertificatesDataEncryptionCertificatesPathConfigRootKey'                                = 'SecureCertificatesDataEncryptionCertificatesPath'
  # Use this if special purpose openSSL configuration files are needed
  'SecureCertificatesOpenSSLConfigsPathConfigRootKey'                                            = 'SecureCertificatesOpenSSLConfigsPath'
  # Use this if obfuscation of file names is desired
  'SecureCertificatesCrossReferenceFilenameConfigRootKey'                                        = 'SecureCertificatesCrossReferenceDNFile'

  #  These define where a Certificate Authority (CA) keeps the records of the CSRs it is given, and a copy of each Certificate it creates and signs
  'SecureCertificatesSigningCertificatesPathConfigRootKey'                                       = 'SecureCertificatesSigningCertificatesPath'
  #'SecureCertificatesSigningCertificatesPrivateKeysRelativePathConfigRootKey' = 'SecureCertificatesSigningCertificatesPrivateKeysRelativePath'
  #'SecureCertificatesSigningCertificatesNewCertificatesRelativePathConfigRootKey' ='SecureCertificatesSigningCertificatesNewCertificatesRelativePath'
  'SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey'           = 'SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePath'
  #'SecureCertificatesSigningCertificatesSerialNumberRelativePathConfigRootKey' ='SecureCertificatesSigningCertificatesSerialNumberRelativePath'

  # These define the latter portion of certificate-related filename (used as the parameter -BaseFileName)
  'SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey'                                  = 'SecureCertificatesCAPassPhraseFileBaseFileName'
  'SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey'                             = 'SecureCertificatesCAEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesCACertificateBaseFileNameConfigRootKey'                                     = 'SecureCertificatesCACertificateBaseFileName'
  'SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey'                           = 'SecureCertificatesSSLServerPassPhraseFileBaseFileName'
  'SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey'                      = 'SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesSSLServerCertificateRequestBaseFileNameConfigRootKey'                       = 'SecureCertificatesSSLServerCertificateRequestBaseFileName'
  'SecureCertificatesSSLServerCertificateBaseFileNameConfigRootKey'                              = 'SecureCertificatesSSLServerCertificateBaseFileName'
  'SecureCertificatesCodeSigningPassPhraseFileBaseFileNameConfigRootKey'                         = 'SecureCertificatesCodeSigningPassPhraseFileBaseFileName'
  'SecureCertificatesCodeSigningEncryptedPrivateKeyBaseFileNameConfigRootKey'                    = 'SecureCertificatesCodeSigningEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesCodeSigningCertificateRequestBaseFileNameConfigRootKey'                     = 'SecureCertificatesCodeSigningCertificateRequestBaseFileName'
  'SecureCertificatesCodeSigningCertificateBaseFileNameConfigRootKey'                            = 'SecureCertificatesCodeSigningCertificateBaseFileName'

  # SecretsManagement
  'SecretVaultBaseDirectoryConfigRootKey'                                                        = 'SecureVaultBasePath'
  'SecretVaultEncryptionKeyFilePathConfigRootKey'                                                = 'SecretVaultEncryptionKeyFilePath'
  'SecretVaultEncryptedPasswordFilePathConfigRootKey'                                            = 'SecretVaultEncryptedPasswordFilePath'
  'SecretVaultModuleNameConfigRootKey'                                                           = 'SecretVaultModuleName'
  'SecretVaultNameConfigRootKey'                                                                 = 'SecretVaultName'
  'SecretVaultDescriptionConfigRootKey'                                                          = 'SecretVaultDescription'
  'SecretVaultKeySizeIntConfigRootKey'                                                           = 'SecretVaultKeySizeInt'
  'SecretVaultPasswordTimeoutConfigRootKey'                                                      = 'SecretVaultPasswordTimeout'
  'SecretVaultPathToKeePassDBConfigRootKey'                                                      = 'SecretVaultPathToKeePassDB'

  # Locations for things that are needed in case of disaster
  'DisasterRecoveryPathConfigRootKey'                                                            = 'DisasterRecoveryPath'
  'DisasterRecoveryBackupPathConfigRootKey'                                                      = 'DisasterRecoveryBackupPath'

  # Container (Machine, VM, Docker) Roles
  'DeveloperComputerRoleConfigRootKey'                                                           = 'DeveloperComputer'
  'DocumentationComputerRoleConfigRootKey'                                                       = 'DocumentationComputer'
  'TestingComputerRoleConfigRootKey'                                                             = 'TestingComputer'
  'CICDComputerRoleConfigRootKey'                                                                = 'CICDComputer'
  'DocFXComputerRoleConfigRootKey'                                                               = 'DocFXComputer'
  'WebServerComputerRoleConfigRootKey'                                                           = 'WebServerComputer'
  'JenkinsControllerComputerRoleConfigRootKey'                                                   = 'JenkinsControllerComputer'
  'JenkinsAgentComputerRoleConfigRootKey'                                                        = 'JenkinsAgentComputer'
  'MSSQLServerComputerRoleConfigRootKey'                                                         = 'MSSQLServerComputer'
  'PlantUMLComputerRoleConfigRootKey'                                                            = 'PlantUMLComputer'
  'CertificateServerComputerRoleConfigRootKey'                                                   = 'CertificateServerComputer'
  'ProGetPackageRepositoryProviderComputerRoleConfigRootKey'                                     = 'ProGetPackageRepositoryProviderComputer'
}

# PackageRepository Uris for Packaging, Deploying, Delivering, Updating
# Uri locations and their component parts for internal and external PackageRepositories
# PackageRepository Uri subkeys are formed as
# 'PackageRepository' + ('External' |'Internal' ) + ('Released' | 'Prerelease') + ('Filesystem' | 'NuGet' | 'PSResourceGet' | 'ChocolateyGet') + ('Production' | 'QualityAssurance') + 'Package' + ('Pull' | 'Push') + 'Uri'
# Every PackageRepository entry needs a 'shortname' as many package providers limit the name of a feed (e.g., proget limits to 50 chars)
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\Profiles\global_ConfigRootKeysFragment.PackageRepositories.ps1'
# PackageRepository values for Filesystem (internal only)

# All Package repositories that use a filesystem can use the default source and drop locations, or specify a full custom paths
# 'PackageRepositoryInternalReleasedFilesystemProductionPackagePushUriConfigRootKey'                       = 'PackageRepositoryInternalReleasedFilesystemProductionPackagePushUri'
# 'PackageRepositoryInternalReleasedFilesystemProductionPackagePullUriConfigRootKey'                       = 'PackageRepositoryInternalReleasedFilesystemProductionPackagePullUri'
# 'PackageRepositoryInternalReleasedFilesystemQualityAssurancePackagePushUriConfigRootKey'                 = 'PackageRepositoryInternalReleasedFilesystemQualityAssurancePackagePushUri'
# 'PackageRepositoryInternalReleasedFilesystemPQualityAssurancePackagePullUriConfigRootKey'                = 'PackageRepositoryInternalReleasedFilesystemQualityAssurancePackagePullUri'
# 'PackageRepositoryInternalPrereleaseFilesystemProductionPackagePushUriConfigRootKey'                     = 'PackageRepositoryInternalPrereleaseFilesystemProductionPackagePushUri'
# 'PackageRepositoryInternalPrereleaseFilesystemProductionPackagePullUriConfigRootKey'                     = 'PackageRepositoryInternalPrereleaseFilesystemProductionPackagePullUri'
# 'PackageRepositoryInternalPrereleaseFilesystemQualityAssurancePackagePushUriConfigRootKey'               = 'PackageRepositoryInternalPrereleaseFilesystemQualityAssurancePackagePushUri'
# 'PackageRepositoryInternalPrereleaseFilesystemQualityAssurancePackagePullUriConfigRootKey'               = 'PackageRepositoryInternalPrereleaseFilesystemQualityAssurancePackagePullUri'

# # External Pull Uris
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriConfigRootKey'                            = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUri'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriConfigRootKey'                      = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUri'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriConfigRootKey'                    = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUri'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriConfigRootKey'              = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUri'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriConfigRootKey'                    = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUri'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriConfigRootKey'              = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUri'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriConfigRootKey'                          = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUri'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriConfigRootKey'                    = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUri'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriConfigRootKey'                  = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUri'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriConfigRootKey'            = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUri'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriConfigRootKey'                  = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUri'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriConfigRootKey'            = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUri'
# # Internal Pull Uris
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriConfigRootKey'                      = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUri'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriConfigRootKey'                    = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUri'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriConfigRootKey'              = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUri'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriConfigRootKey'                    = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUri'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriConfigRootKey'              = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUri'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriConfigRootKey'                          = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUri'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriConfigRootKey'                    = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUri'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriConfigRootKey'                  = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUri'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriConfigRootKey'            = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUri'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriConfigRootKey'                  = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUri'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriConfigRootKey'            = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUri'
# # External Push Uris
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriConfigRootKey'                            = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUri'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriConfigRootKey'                      = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUri'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriConfigRootKey'                    = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUri'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriConfigRootKey'              = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUri'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriConfigRootKey'                    = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUri'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriConfigRootKey'              = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUri'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriConfigRootKey'                          = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUri'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriConfigRootKey'                    = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUri'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriConfigRootKey'                  = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUri'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriConfigRootKey'            = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUri'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriConfigRootKey'                  = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUri'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriConfigRootKey'            = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUri'
# # Internal Push Uris
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriConfigRootKey'                            = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUri'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriConfigRootKey'                      = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUri'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriConfigRootKey'                    = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUri'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriConfigRootKey'              = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUri'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriConfigRootKey'                    = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUri'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriConfigRootKey'              = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUri'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriConfigRootKey'                          = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUri'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriConfigRootKey'                    = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUri'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriConfigRootKey'                  = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUri'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriConfigRootKey'            = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUri'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriConfigRootKey'                  = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUri'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriConfigRootKey'            = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUri'

# # The individual components that make up the pull and push Uris for PackageRepository Http Servers
# # Every push or pull Uri is made up of 'Protocol' + 'Server' + 'Port' + 'Path' + 'QueryString'. Path defaults to '/' and QueryString defaults to ''
# # Pull Uri individual components
# # External Pull Uri components
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriSchemeConfigRootKey'                    = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriProtocol'
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriHostConfigRootKey'                      = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriServer'
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriPortConfigRootKey'                        = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriPort'
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriPathConfigRootKey'                        = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriPath'
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriQueryStringConfigRootKey'                 = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriQueryString'
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePullFeedShortNameConfigRootKey'                  = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullFeedShortName'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriSchemeConfigRootKey'              = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriHostConfigRootKey'                = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriPortConfigRootKey'                  = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriPathConfigRootKey'                  = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriQueryStringConfigRootKey'           = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullFeedShortNameConfigRootKey'            = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullFeedShortName'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriSchemeConfigRootKey'            = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriProtocol'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriHostConfigRootKey'              = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriServer'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriPortConfigRootKey'                = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriPort'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriPathConfigRootKey'                = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriPath'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullUriQueryString'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullFeedShortNameConfigRootKey'          = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePullFeedShortName'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriSchemeConfigRootKey'      = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriHostConfigRootKey'        = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriPortConfigRootKey'          = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriPathConfigRootKey'          = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriQueryStringConfigRootKey'   = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullFeedShortNameConfigRootKey'    = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePullFeedShortName'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriSchemeConfigRootKey'            = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriProtocol'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriHostConfigRootKey'              = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriServer'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriPortConfigRootKey'                = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriPort'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriPathConfigRootKey'                = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriPath'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriQueryString'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullFeedShortNameConfigRootKey'          = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullFeedShortName'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriSchemeConfigRootKey'      = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriHostConfigRootKey'        = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriPortConfigRootKey'          = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriPathConfigRootKey'          = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriQueryStringConfigRootKey'   = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullFeedShortNameConfigRootKey'    = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullFeedShortName'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriSchemeConfigRootKey'                  = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriProtocol'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriHostConfigRootKey'                    = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriServer'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriPortConfigRootKey'                      = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriPort'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriPathConfigRootKey'                      = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriPath'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriQueryStringConfigRootKey'               = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriQueryString'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullFeedShortNameConfigRootKey'                = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullFeedShortName'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriSchemeConfigRootKey'            = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriHostConfigRootKey'              = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriPortConfigRootKey'                = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriPathConfigRootKey'                = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullFeedShortNameConfigRootKey'          = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullFeedShortName'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriSchemeConfigRootKey'          = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriProtocol'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriHostConfigRootKey'            = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriServer'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriPortConfigRootKey'              = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriPort'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriPathConfigRootKey'              = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriPath'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriQueryStringConfigRootKey'       = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullUriQueryString'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullFeedShortNameConfigRootKey'        = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePullFeedShortName'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriSchemeConfigRootKey'    = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriHostConfigRootKey'      = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriPortConfigRootKey'        = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriPathConfigRootKey'        = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriQueryStringConfigRootKey' = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullFeedShortNameConfigRootKey'  = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePullFeedShortName'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriSchemeConfigRootKey'          = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriProtocol'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriHostConfigRootKey'            = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriServer'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriPortConfigRootKey'              = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriPort'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriPathConfigRootKey'              = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriPath'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriQueryStringConfigRootKey'       = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriQueryString'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullFeedShortNameConfigRootKey'        = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullFeedShortName'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriSchemeConfigRootKey'    = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriHostConfigRootKey'      = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPortConfigRootKey'        = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPathConfigRootKey'        = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriQueryStringConfigRootKey' = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullFeedShortNameConfigRootKey'  = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullFeedShortName'
# # External Push Uri components
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriSchemeConfigRootKey'                    = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriProtocol'
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriHostConfigRootKey'                      = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriServer'
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriPortConfigRootKey'                        = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriPort'
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriPathConfigRootKey'                        = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriPath'
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriQueryStringConfigRootKey'                 = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriQueryString'
# 'PackageRepositoryExternalReleasedNuGetProductionPackagePushShortNameConfigRootKey'                      = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushShortName'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriSchemeConfigRootKey'              = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriHostConfigRootKey'                = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriPortConfigRootKey'                  = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriPathConfigRootKey'                  = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriQueryStringConfigRootKey'           = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushShortNameConfigRootKey'                = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushShortName'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriSchemeConfigRootKey'            = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriProtocol'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriHostConfigRootKey'              = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriServer'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriPortConfigRootKey'                = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriPort'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriPathConfigRootKey'                = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriPath'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushUriQueryString'
# 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushShortNameConfigRootKey'              = 'PackageRepositoryExternalReleasedPSResourceGetProductionPackagePushShortName'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriSchemeConfigRootKey'      = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriHostConfigRootKey'        = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriPortConfigRootKey'          = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriPathConfigRootKey'          = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriQueryStringConfigRootKey'   = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushShortNameConfigRootKey'        = 'PackageRepositoryExternalReleasedPSResourceGetQualityAssurancePackagePushShortName'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriSchemeConfigRootKey'            = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriProtocol'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriHostConfigRootKey'              = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriServer'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriPortConfigRootKey'                = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriPort'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriPathConfigRootKey'                = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriPath'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriQueryString'
# 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushShortNameConfigRootKey'              = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushShortName'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriSchemeConfigRootKey'      = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriHostConfigRootKey'        = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriPortConfigRootKey'          = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriPathConfigRootKey'          = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriQueryStringConfigRootKey'   = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushShortNameConfigRootKey'        = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushShortName'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriSchemeConfigRootKey'                  = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriProtocol'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriHostConfigRootKey'                    = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriServer'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriPortConfigRootKey'                      = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriPort'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriPathConfigRootKey'                      = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriPath'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriQueryStringConfigRootKey'               = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriQueryString'
# 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushShortNameConfigRootKey'                    = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushShortName'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriSchemeConfigRootKey'            = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriHostConfigRootKey'              = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriPortConfigRootKey'                = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriPathConfigRootKey'                = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushShortNameConfigRootKey'              = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushShortName'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriSchemeConfigRootKey'          = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriProtocol'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriHostConfigRootKey'            = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriServer'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriPortConfigRootKey'              = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriPort'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriPathConfigRootKey'              = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriPath'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriQueryStringConfigRootKey'       = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushUriQueryString'
# 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushShortNameConfigRootKey'            = 'PackageRepositoryExternalPrereleasePSResourceGetProductionPackagePushShortName'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriSchemeConfigRootKey'    = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriHostConfigRootKey'      = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriPortConfigRootKey'        = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriPathConfigRootKey'        = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriQueryStringConfigRootKey' = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushShortNameConfigRootKey'      = 'PackageRepositoryExternalPrereleasePSResourceGetQualityAssurancePackagePushShortName'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriSchemeConfigRootKey'          = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriProtocol'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriHostConfigRootKey'            = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriServer'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriPortConfigRootKey'              = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriPort'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriPathConfigRootKey'              = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriPath'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriQueryStringConfigRootKey'       = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriQueryString'
# 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushShortNameConfigRootKey'            = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushShortName'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriSchemeConfigRootKey'    = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriHostConfigRootKey'      = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPortConfigRootKey'        = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPathConfigRootKey'        = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriQueryStringConfigRootKey' = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushShortNameConfigRootKey'      = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushShortName'
# # Internal Uri components
# # Internal, Released, NuGet, Production, Pull and Push
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriSchemeConfigRootKey'                    = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriProtocol'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriHostConfigRootKey'                      = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriServer'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriPortConfigRootKey'                        = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriPort'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriPathConfigRootKey'                        = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriPath'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriQueryStringConfigRootKey'                 = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriQueryString'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriConfigRootKey'                            = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUri'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePullFeedShortNameConfigRootKey'                  = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullFeedShortName'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePullFeedApiKeyNameConfigRootKey'                 = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullFeedApiKeyName'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePullFeedConfigRootKey'                           = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullFeed'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriSchemeConfigRootKey'                    = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriProtocol'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriHostConfigRootKey'                      = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriServer'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriPortConfigRootKey'                        = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriPort'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriPathConfigRootKey'                        = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriPath'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriQueryStringConfigRootKey'                 = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriQueryString'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePushFeedShortNameConfigRootKey'                  = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushFeedShortName'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePushFeedApiKeyNameConfigRootKey'                 = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushFeedApiKeyName'
# 'PackageRepositoryInternalReleasedNuGetProductionPackagePushFeedConfigRootKey'                           = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushFeed'

# # Internal, Released, NuGet, QualityAssurance, Pull and Push
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriSchemeConfigRootKey'              = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriHostConfigRootKey'                = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriPortConfigRootKey'                  = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriPathConfigRootKey'                  = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriQueryStringConfigRootKey'           = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullFeedShortNameConfigRootKey'            = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullFeedShortName'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullFeedApiKeyNameConfigRootKey'           = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullFeedApiKeyName'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullFeedConfigRootKey'                     = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullFeed'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriSchemeConfigRootKey'              = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriHostConfigRootKey'                = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriPortConfigRootKey'                  = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriPathConfigRootKey'                  = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriQueryStringConfigRootKey'           = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushFeedShortNameConfigRootKey'            = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushFeedShortName'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushFeedApiKeyNameConfigRootKey'           = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushFeedApiKeyName'
# 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushFeedConfigRootKey'                     = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushFeed'

# # Internal, Released, PSResourceGet, Production, Pull and Push
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriSchemeConfigRootKey'            = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriProtocol'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriHostConfigRootKey'              = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriServer'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriPortConfigRootKey'                = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriPort'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriPathConfigRootKey'                = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriPath'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriQueryString'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullFeedShortNameConfigRootKey'          = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullFeedShortName'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullFeedApiKeyNameConfigRootKey'         = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullFeedApiKeyName'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullFeedConfigRootKey'                   = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullFeed'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriSchemeConfigRootKey'            = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriProtocol'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriHostConfigRootKey'              = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriServer'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriPortConfigRootKey'                = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriPort'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriPathConfigRootKey'                = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriPath'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushUriQueryString'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushFeedShortNameConfigRootKey'          = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushFeedShortName'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushFeedApiKeyNameConfigRootKey'         = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushFeedApiKeyName'
# 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushFeedConfigRootKey'                   = 'PackageRepositoryInternalReleasedPSResourceGetProductionPackagePushFeed'

# # Internal, Released, PSResourceGet, QualityAssurance, Pull and Push
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriSchemeConfigRootKey'      = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriHostConfigRootKey'        = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriPortConfigRootKey'          = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriPathConfigRootKey'          = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriQueryStringConfigRootKey'   = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullFeedShortNameConfigRootKey'    = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullFeedShortName'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullFeedApiKeyNameConfigRootKey'   = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullFeedApiKeyName'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullFeedConfigRootKey'             = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePullFeed'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriSchemeConfigRootKey'      = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriHostConfigRootKey'        = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriPortConfigRootKey'          = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriPathConfigRootKey'          = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriQueryStringConfigRootKey'   = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushFeedShortNameConfigRootKey'    = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushFeedShortName'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushFeedApiKeyNameConfigRootKey'   = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushFeedApiKeyName'
# 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushFeedConfigRootKey'             = 'PackageRepositoryInternalReleasedPSResourceGetQualityAssurancePackagePushFeed'

# # Internal, Released, ChocolateyGet, Production, Pull and Push
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriSchemeConfigRootKey'            = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriProtocol'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriHostConfigRootKey'              = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriServer'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriPortConfigRootKey'                = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriPort'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriPathConfigRootKey'                = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriPath'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriQueryString'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullFeedShortNameConfigRootKey'          = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullFeedShortName'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriSchemeConfigRootKey'            = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriProtocol'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriHostConfigRootKey'              = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriServer'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriPortConfigRootKey'                = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriPort'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriPathConfigRootKey'                = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriPath'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriQueryString'
# 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushShortNameConfigRootKey'              = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushShortName'

# # Internal, Released, ChocolateyGet, QualityAssurance, Pull and Push
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriSchemeConfigRootKey'      = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriHostConfigRootKey'        = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriPortConfigRootKey'          = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriPathConfigRootKey'          = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriQueryStringConfigRootKey'   = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullFeedShortNameConfigRootKey'    = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullFeedShortName'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriSchemeConfigRootKey'      = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriHostConfigRootKey'        = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriPortConfigRootKey'          = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriPathConfigRootKey'          = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriQueryStringConfigRootKey'   = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushShortNameConfigRootKey'        = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushShortName'

# # Internal, Prerelease, NuGet, Production, Pull and Push
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriSchemeConfigRootKey'                  = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriProtocol'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriHostConfigRootKey'                    = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriServer'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriPortConfigRootKey'                      = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriPort'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriPathConfigRootKey'                      = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriPath'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriQueryStringConfigRootKey'               = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriQueryString'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullFeedShortNameConfigRootKey'                = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullFeedShortName'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriSchemeConfigRootKey'                  = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriProtocol'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriHostConfigRootKey'                    = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriServer'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriPortConfigRootKey'                      = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriPort'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriPathConfigRootKey'                      = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriPath'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriQueryStringConfigRootKey'               = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriQueryString'
# 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushShortNameConfigRootKey'                    = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushShortName'


# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriSchemeConfigRootKey'            = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriHostConfigRootKey'              = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriPortConfigRootKey'                = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriPathConfigRootKey'                = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullFeedShortNameConfigRootKey'          = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullFeedShortName'

# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriSchemeConfigRootKey'          = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriProtocol'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriHostConfigRootKey'            = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriServer'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriPortConfigRootKey'              = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriPort'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriPathConfigRootKey'              = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriPath'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriQueryStringConfigRootKey'       = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullUriQueryString'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullFeedShortNameConfigRootKey'        = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePullFeedShortName'

# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriSchemeConfigRootKey'    = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriHostConfigRootKey'      = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriPortConfigRootKey'        = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriPathConfigRootKey'        = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriQueryStringConfigRootKey' = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullFeedShortNameConfigRootKey'  = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePullFeedShortName'

# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriSchemeConfigRootKey'          = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriProtocol'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriHostConfigRootKey'            = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriServer'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriPortConfigRootKey'              = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriPort'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriPathConfigRootKey'              = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriPath'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriQueryStringConfigRootKey'       = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriQueryString'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullFeedShortNameConfigRootKey'        = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullFeedShortName'

# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriSchemeConfigRootKey'    = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriProtocol'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriHostConfigRootKey'      = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriServer'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPortConfigRootKey'        = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPort'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPathConfigRootKey'        = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPath'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriQueryStringConfigRootKey' = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriQueryString'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullFeedShortNameConfigRootKey'  = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullFeedShortName'
# # Internal Push Uri components
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriSchemeConfigRootKey'            = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriHostConfigRootKey'              = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriPortConfigRootKey'                = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriPathConfigRootKey'                = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushShortNameConfigRootKey'              = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushShortName'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriSchemeConfigRootKey'          = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriProtocol'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriHostConfigRootKey'            = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriServer'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriPortConfigRootKey'              = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriPort'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriPathConfigRootKey'              = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriPath'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriQueryStringConfigRootKey'       = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushUriQueryString'
# 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushShortNameConfigRootKey'            = 'PackageRepositoryInternalPrereleasePSResourceGetProductionPackagePushShortName'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriSchemeConfigRootKey'    = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriHostConfigRootKey'      = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriPortConfigRootKey'        = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriPathConfigRootKey'        = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriQueryStringConfigRootKey' = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushShortNameConfigRootKey'      = 'PackageRepositoryInternalPrereleasePSResourceGetQualityAssurancePackagePushShortName'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriSchemeConfigRootKey'          = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriProtocol'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriHostConfigRootKey'            = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriServer'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriPortConfigRootKey'              = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriPort'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriPathConfigRootKey'              = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriPath'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriQueryStringConfigRootKey'       = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriQueryString'
# 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushShortNameConfigRootKey'            = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushShortName'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriSchemeConfigRootKey'    = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriProtocol'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriHostConfigRootKey'      = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriServer'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPortConfigRootKey'        = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPort'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPathConfigRootKey'        = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPath'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriQueryStringConfigRootKey' = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriQueryString'
# 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushShortNameConfigRootKey'      = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushShortName'


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
  $global:configRootKeys['DeveloperComputerRoleConfigRootKey']                       = @{DependsOn = $null }
  $global:configRootKeys['DocumentationComputerRoleConfigRootKey']                   = @{DependsOn = @($global:configRootKeys['DocFXComputerRoleConfigRootKey'], $global:configRootKeys['PlantUMLComputerRoleConfigRootKey']) }
  $global:configRootKeys['TestingComputerRoleConfigRootKey']                         = @{DependsOn = $null }
  $global:configRootKeys['WebServerComputerRoleConfigRootKey']                       = @{DependsOn = $null }
  $global:configRootKeys['CertificateServerComputerRoleConfigRootKey']               = @{DependsOn = $null }
  $global:configRootKeys['CICDComputerRoleConfigRootKey']                            = @{DependsOn = $null }
  $global:configRootKeys['JenkinsControllerComputerRoleConfigRootKey']               = @{DependsOn = $null }
  $global:configRootKeys['JenkinsAgentComputerRoleConfigRootKey']                    = @{DependsOn = $null }
  $global:configRootKeys['MSSQLServerComputerRoleConfigRootKey']                     = @{DependsOn = $null }
  $global:configRootKeys['DocFXComputerRoleConfigRootKey']                           = @{DependsOn = $null }
  $global:configRootKeys['PlantUMLComputerRoleConfigRootKey']                        = @{DependsOn = $null }
  $global:configRootKeys['ProGetPackageRepositoryProviderComputerRoleConfigRootKey'] = @{DependsOn = $null }
}

