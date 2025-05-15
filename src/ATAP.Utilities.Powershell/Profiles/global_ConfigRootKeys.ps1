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
  'HydrusAPIServerConfigRootKey'                                                                 = 'HydrusAPIServer'
  'HydrusAPIProtocolConfigRootKey'                                                               = 'HydrusAPIProtocol'
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
  # the subdirectory name under the GeneratedRelativePath where the Powershell Packages are placed
  'GeneratedPowershellPackagesConfigRootKey'                                                     = 'GeneratedPowershellPackagesSubdirectory'
  # the subdirectory name under the GeneratedPowershellModules where the Powershell package files for the Powershell Gallery are placed
  'GeneratedPowershellPackagesPowershellGetConfigRootKey'                                        = 'GeneratedPowershellGetPackageSubdirectory'
  # the subdirectory name under the GeneratedPowershellModules where the Powershell package files for the Nuget.org server are placed
  'GeneratedPowershellPackagesNuGetConfigRootKey'                                                = 'GeneratedNuGetPackageSubdirectory'
  # the subdirectory name under the GeneratedPowershellModules where the Powershell package files for the ChocolateyGet server are placed
  'GeneratedPowershellPackagesChocolateyGetConfigRootKey'                                        = 'GeneratedChocolateyGetPackageSubdirectory'

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

  # Packaging, Deploying, Delivering, Updating
  # All Package repositories that use a filesystem can use the default source and drop locations, or specify a full custom paths
  'RepositoryFileSystemPackageSourceLocationBaseDirectoryDefaultConfigRootKey'                   = 'RepositoryFileSystemPackageSourceLocationBasePathDefault'
  'RepositoryFileSystemPackageDropLocationBasePathDefaultConfigRootKey'                          = 'RepositoryFileSystemPackageDropLocationBasePathDefault'
  # The repository names by which each of the various repositories for Powershell packages are known. and their details
  # The name of the repository for Packages that are in NuGet format
  # ToDo: The Filesystem locations, and web server URIs need both a source and a drop settings base for every provider/location pair. Using just Source value currently
  'RepositoryNuGetFilesystemQualityAssurancePackageNameConfigRootKey'                            = 'RepositoryNuGetFilesystemQualityAssurancePackage'
  'RepositoryNuGetFilesystemQualityAssurancePackagePathConfigRootKey'                            = 'RepositoryNuGetFilesystemQualityAssurancePackagePath'
  'RepositoryNuGetFilesystemProductionPackageNameConfigRootKey'                                  = 'RepositoryNuGetFilesystemProductionPackage'
  'RepositoryNuGetFilesystemProductionPackagePathConfigRootKey'                                  = 'RepositoryNuGetFilesystemProductionPackagePath'
  'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageNameConfigRootKey'             = 'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackage'
  'RepositoryNuGetQualityAssuranceWebServerProductionPackageNameConfigRootKey'                   = 'RepositoryNuGetQualityAssuranceWebServerProductionPackage'
  'RepositoryNuGetProductionWebServerQualityAssurancePackageNameConfigRootKey'                   = 'RepositoryNuGetProductionWebServerQualityAssurancePackage'
  'RepositoryNuGetProductionWebServerProductionPackageNameConfigRootKey'                         = 'RepositoryNuGetProductionWebServerProductionPackage'

  # The name of the repository for Packages that are in PowershellGet format
  'RepositoryPowershellGetFilesystemQualityAssurancePackageNameConfigRootKey'                    = 'RepositoryPowershellGetFilesystemQualityAssurancePackage'
  'RepositoryPowershellGetFilesystemQualityAssurancePackagePathConfigRootKey'                    = 'RepositoryPowershellGetFilesystemQualityAssurancePackagePath'
  'RepositoryPowershellGetFilesystemProductionPackageNameConfigRootKey'                          = 'RepositoryPowershellGetFilesystemProductionPackage'
  'RepositoryPowershellGetFilesystemProductionPackagePathConfigRootKey'                          = 'RepositoryPowershellGetFilesystemProductionPackagePath'
  'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageNameConfigRootKey'     = 'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackage'
  'RepositoryPowershellGetQualityAssuranceWebServerProductionPackageNameConfigRootKey'           = 'RepositoryPowershellGetQualityAssuranceWebServerProductionPackage'
  'RepositoryPowershellGetProductionWebServerQualityAssurancePackageNameConfigRootKey'           = 'RepositoryPowershellGetProductionWebServerQualityAssurancePackage'
  'RepositoryPowershellGetProductionWebServerProductionPackageNameConfigRootKey'                 = 'RepositoryPowershellGetProductionWebServerProductionPackage'

  # The name of the repository for Packages that are in ChocolateyGet formatRepository
  'RepositoryChocolateyGetFilesystemQualityAssurancePackageNameConfigRootKey'                    = 'RepositoryChocolateyGetFilesystemQualityAssurancePackage'
  'RepositoryChocolateyGetFilesystemQualityAssurancePackagePathConfigRootKey'                    = 'RepositoryChocolateyGetFilesystemQualityAssurancePackagePath'
  'RepositoryChocolateyGetFilesystemProductionPackageNameConfigRootKey'                          = 'RepositoryChocolateyGetFilesystemProductionPackage'
  'RepositoryChocolateyGetFilesystemProductionPackagePathConfigRootKey'                          = 'RepositoryChocolateyGetFilesystemProductionPackagePath'
  'RepositoryChocolateyGetQualityAssuranceWebServerQualityAssurancePackageNameConfigRootKey'     = 'RepositoryChocolateyGetQualityAssuranceWebServerQualityAssurancePackage'
  'RepositoryChocolateyGetQualityAssuranceWebServerProductionPackageNameConfigRootKey'           = 'RepositoryChocolateyGetQualityAssuranceWebServerProductionPackage'
  'RepositoryChocolateyGetProductionWebServerQualityAssurancePackageNameConfigRootKey'           = 'RepositoryChocolateyGetProductionWebServerQualityAssurancePackage'
  'RepositoryChocolateyGetProductionWebServerProductionPackageNameConfigRootKey'                 = 'RepositoryChocolateyGetProductionWebServerProductionPackage'
  # URI details for web-based repositories
  # URI Details for NuGet Web Server
  'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey'         = 'NuGetQualityAssuranceWebServerQualityAssurancePackageProtocol'
  'RepositoryNuGetQualityAssuranceWebServerProductionPackageProtocolConfigRootKey'               = 'NuGetQualityAssuranceWebServerProductionPackageProtocol'
  'RepositoryNuGetProductionWebServerQualityAssurancePackageProtocolConfigRootKey'               = 'NuGetProductionWebServerQualityAssurancePackageProtocol'
  'RepositoryNuGetProductionWebServerProductionPackageProtocolConfigRootKey'                     = 'NuGetProductionWebServerProductionPackageProtocol'
  'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey'           = 'NuGetQualityAssuranceWebServerQualityAssurancePackageServer'
  'RepositoryNuGetQualityAssuranceWebServerProductionPackageServerConfigRootKey'                 = 'NuGetQualityAssuranceWebServerProductionPackageServer'
  'RepositoryNuGetProductionWebServerQualityAssurancePackageServerConfigRootKey'                 = 'NuGetProductionWebServerQualityAssurancePackageServer'
  'RepositoryNuGetProductionWebServerProductionPackageServerConfigRootKey'                       = 'NuGetProductionWebServerProductionPackageServer'
  'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey'             = 'NuGetQualityAssuranceWebServerQualityAssurancePackagePort'
  'RepositoryNuGetQualityAssuranceWebServerProductionPackagePortConfigRootKey'                   = 'NuGetQualityAssuranceWebServerProductionPackagePort'
  'RepositoryNuGetProductionWebServerQualityAssurancePackagePortConfigRootKey'                   = 'NuGetProductionWebServerQualityAssurancePackagePort'
  'RepositoryNuGetProductionWebServerProductionPackagePortConfigRootKey'                         = 'NuGetProductionWebServerProductionPackagePort'
  # URIs For NuGetWebServer
  'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey'              = 'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageURI'
  'RepositoryNuGetQualityAssuranceWebServerProductionPackageURIConfigRootKey'                    = 'RepositoryNuGetQualityAssuranceWebServerProductionPackageURI'
  'RepositoryNuGetProductionWebServerQualityAssurancePackageURIConfigRootKey'                    = 'RepositoryNuGetProductionWebServerQualityAssurancePackageURI'
  'RepositoryNuGetProductionWebServerProductionPackageURIConfigRootKey'                          = 'RepositoryNuGetProductionWebServerProductionPackageURI'

  # URI Details for PowershellGet Web Server
  'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey' = 'PowershellGetQualityAssuranceWebServerQualityAssurancePackageProtocol'
  'RepositoryPowershellGetQualityAssuranceWebServerProductionPackageProtocolConfigRootKey'       = 'PowershellGetQualityAssuranceWebServerProductionPackageProtocol'
  'RepositoryPowershellGetProductionWebServerQualityAssurancePackageProtocolConfigRootKey'       = 'PowershellGetProductionWebServerQualityAssurancePackageProtocol'
  'RepositoryPowershellGetProductionWebServerProductionPackageProtocolConfigRootKey'             = 'PowershellGetProductionWebServerProductionPackageProtocol'
  'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey'   = 'PowershellGetQualityAssuranceWebServerQualityAssurancePackageServer'
  'RepositoryPowershellGetQualityAssuranceWebServerProductionPackageServerConfigRootKey'         = 'PowershellGetQualityAssuranceWebServerProductionPackageServer'
  'RepositoryPowershellGetProductionWebServerQualityAssurancePackageServerConfigRootKey'         = 'PowershellGetProductionWebServerQualityAssurancePackageServer'
  'RepositoryPowershellGetProductionWebServerProductionPackageServerConfigRootKey'               = 'PowershellGetProductionWebServerProductionPackageServer'
  'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey'     = 'PowershellGetQualityAssuranceWebServerQualityAssurancePackagePort'
  'RepositoryPowershellGetQualityAssuranceWebServerProductionPackagePortConfigRootKey'           = 'PowershellGetQualityAssuranceWebServerProductionPackagePort'
  'RepositoryPowershellGetProductionWebServerQualityAssurancePackagePortConfigRootKey'           = 'PowershellGetProductionWebServerQualityAssurancePackagePort'
  'RepositoryPowershellGetProductionWebServerProductionPackagePortConfigRootKey'                 = 'PowershellGetProductionWebServerProductionPackagePort'
  # URIs For PowershellGetWebServer
  'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey'      = 'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageURI'
  'RepositoryPowershellGetQualityAssuranceWebServerProductionPackageURIConfigRootKey'            = 'RepositoryPowershellGetQualityAssuranceWebServerProductionPackageURI'
  'RepositoryPowershellGetProductionWebServerQualityAssurancePackageURIConfigRootKey'            = 'RepositoryPowershellGetProductionWebServerQualityAssurancePackageURI'
  'RepositoryPowershellGetProductionWebServerProductionPackageURIConfigRootKey'                  = 'RepositoryPowershellGetProductionWebServerProductionPackageURI'

  # URI Details for ChocolateyGet Web Server
  'RepositoryChocolateyGetQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey' = 'ChocolateyGetQualityAssuranceWebServerQualityAssurancePackageProtocol'
  'RepositoryChocolateyGetQualityAssuranceWebServerProductionPackageProtocolConfigRootKey'       = 'ChocolateyGetQualityAssuranceWebServerProductionPackageProtocol'
  'RepositoryChocolateyGetProductionWebServerQualityAssurancePackageProtocolConfigRootKey'       = 'ChocolateyGetProductionWebServerQualityAssurancePackageProtocol'
  'RepositoryChocolateyGetProductionWebServerProductionPackageProtocolConfigRootKey'             = 'ChocolateyGetProductionWebServerProductionPackageProtocol'
  'RepositoryChocolateyGetQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey'   = 'ChocolateyGetQualityAssuranceWebServerQualityAssurancePackageServer'
  'RepositoryChocolateyGetQualityAssuranceWebServerProductionPackageServerConfigRootKey'         = 'ChocolateyGetQualityAssuranceWebServerProductionPackageServer'
  'RepositoryChocolateyGetProductionWebServerQualityAssurancePackageServerConfigRootKey'         = 'ChocolateyGetProductionWebServerQualityAssurancePackageServer'
  'RepositoryChocolateyGetProductionWebServerProductionPackageServerConfigRootKey'               = 'ChocolateyGetProductionWebServerProductionPackageServer'
  'RepositoryChocolateyGetQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey'     = 'ChocolateyGetQualityAssuranceWebServerQualityAssurancePackagePort'
  'RepositoryChocolateyGetQualityAssuranceWebServerProductionPackagePortConfigRootKey'           = 'ChocolateyGetQualityAssuranceWebServerProductionPackagePort'
  'RepositoryChocolateyGetProductionWebServerQualityAssurancePackagePortConfigRootKey'           = 'ChocolateyGetProductionWebServerQualityAssurancePackagePort'
  'RepositoryChocolateyGetProductionWebServerProductionPackagePortConfigRootKey'                 = 'ChocolateyGetProductionWebServerProductionPackagePort'
  # URIs For ChocolateyGetWebServer
  'RepositoryChocolateyGetQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey'      = 'RepositoryChocolateyGetQualityAssuranceWebServerQualityAssurancePackageURI'
  'RepositoryChocolateyGetQualityAssuranceWebServerProductionPackageURIConfigRootKey'            = 'RepositoryChocolateyGetQualityAssuranceWebServerProductionPackageURI'
  'RepositoryChocolateyGetProductionWebServerQualityAssurancePackageURIConfigRootKey'            = 'RepositoryChocolateyGetProductionWebServerQualityAssurancePackageURI'
  'RepositoryChocolateyGetProductionWebServerProductionPackageURIConfigRootKey'                  = 'RepositoryChocolateyGetProductionWebServerProductionPackageURI'

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

