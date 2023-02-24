# ToDo comment based help
$global:configRootKeys = @{
  'ProgramFilesConfigRootKey'                                                                    = 'ProgramFiles'
  'ProgramDataConfigRootKey'                                                                     = 'ProgramData'
  'ATAPUtilitiesVersionConfigRootKey'                                                            = 'ATAPUtilitiesVersion'
  'ENVIRONMENTConfigRootKey'                                                                     = 'Environment'
  'IsElevatedConfigRootKey'                                                                      = 'IsElevated'
  'CloudBasePathConfigRootKey'                                                                   = 'CloudBasePath'
  'DropboxBasePathConfigRootKey'                                                                 = 'DropboxBasePath'
  'GoogleDriveBasePathConfigRootKey'                                                             = 'GoogleDriveBasePath'
  'DropboxAccessTokenConfigRootKey'                                                              = 'DropboxAccessToken'
  'OneDriveBasePathConfigRootKey'                                                                = 'OneDriveBasePath'
  'FastTempBasePathConfigRootKey'                                                                = 'FAST_TEMP_BASE_PATH'
  'BigTempBasePathConfigRootKey'                                                                 = 'BIG_TEMP_BASE_PATH'
  'SecureTempBasePathConfigRootKey'                                                              = 'SECURE_TEMP_BASE_PATH'
  'ChocolateyPackagesConfigRootKey'                                                              = 'ChocolateyPackages'
  'ErlangHomeDirConfigRootKey'                                                                   = 'ErlangHomeDir'
  'GIT_CONFIG_GLOBALConfigRootKey'                                                               = 'GIT_CONFIG_GLOBAL'
  'GitExePathConfigRootKey'                                                                      = 'GitExePath'
  'JavaExePathConfigRootKey'                                                                     = 'JavaExePath'
  # Jenkins CI/CD confguration keys
  'JenkinsNodeRolesConfigRootKey'                                                                = 'JenkinsNodeRoles'
  # Jenkins Environment Variables
  # JENKINS_HOME applies onbly to jenkins Controller nodes
  'JENKINS_HOMEConfigRootKey'                                                                    = 'JENKINS_HOME'
  # These Jenkins Environment Variables are used to access a Jenkins Controller and Authenticate
  'JENKINS_URLConfigRootKey'                                                                     = 'JENKINS_URL'
  'JENKINS_USER_IDConfigRootKey'                                                                 = 'JENKINS_USER_ID'
  'JENKINS_API_TOKENConfigRootKey'                                                               = 'JENKINS_API_TOKEN'
  'ChocolateyInstallDirConfigRootKey'                                                            = 'ChocolateyInstall'
  'ChocolateyBinDirConfigRootKey'                                                                = 'ChocolateyBinDir'
  'ChocolateyLibDirConfigRootKey'                                                                = 'ChocolateyLibDir'
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

  # Used by ansible
  'ansible_remote_tmpConfigRootKey'                                                              = 'ansible_remote_tmp'
  'AnsibleGroupNamesConfigRootKey'                                                               = 'AnsibleGroupNames'
  'AnsibleHostNamesConfigRootKey'                                                                = 'AnsibleHostNames'
  'AnsibleRoleNamesConfigRootKey'                                                                = 'AnsibleRoleNames'


  # Computer roles (used in the JenkinsNodeRoles)
  'WindowsCodeBuildConfigRootKey'                                                                = 'WindowsCodeBuild'
  'WindowsUnitTestConfigRootKey'                                                                 = 'WindowsUnitTest'
  'WindowsIntegrationTestConfigRootKey'                                                          = 'WindowIntegrationTest'
  'WindowsDocumentationBuildConfigRootKey'                                                       = 'WindowsDocumentationBuild'

  # The subdirectory name under a repository root dir where files generated by the developer build and CI/CD process build are placed
  'GeneratedRelativePathConfigRootKey'                                                           = 'GeneratedSubdirectory'
  # the subdirectory name under the GeneratedRelativePath where the Powershell Module files are placed
  'GeneratedPowershellModuleConfigRootKey'                                                       = 'GeneratedPowerShellModuleSubdirectory'
  # the subdirectory name under the GeneratedRelativePath where the Powershell Packages are placed
  'GeneratedPowershellPackagesConfigRootKey'                                                     = 'GeneratedPowershellPackagesSubdirectory'
  # the subdirectory name under the GeneratedPowershellModules where the Powershell package files for the Powershell Gallery are placed
  'GeneratedPowershellPackagesPowershellGetConfigRootKey'                                        = 'GeneratedPowershellGetPackageSubdirectory'
  # the subdirectory name under the GeneratedPowershellModules where the Powershell package files for the Nuget.org server are placed
  'GeneratedPowershellPackagesNuGetConfigRootKey'                                                = 'GeneratedNuGetPackageSubdirectory'
  # the subdirectory name under the GeneratedPowershellModules where the Powershell package files for the Chocolatey server are placed
  'GeneratedPowershellPackagesChocolateyGetConfigRootKey'                                        = 'GeneratedChocolateyPackageSubdirectory'

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
  'RepositoryFileSystemPackageSourceLocationBasePathDefaultConfigRootKey'                        = 'RepositoryFileSystemPackageSourceLocationBasePathDefault'
  'RepositoryFileSystemPackageDropLocationBasePathDefaultConfigRootKey'                          = 'RepositoryFileSystemPackageDropLocationBasePathDefault'
  # The repository names by which each of the various repositories for Powershell packages are known. and their details
  # The name of the repository for Packages that are in NuGet format
  'RepositoryNuGetFilesystemDevelopmentPackageNameConfigRootKey'                                 = 'NuGetFilesystemDevelopmentPackage'
  # ToDo: The Filesystem locations, and web server URIs need both a source and a drop settings base for every provider/location pair. Using just Source value currently
  'RepositoryNuGetFilesystemDevelopmentPackagePathConfigRootKey'                                 = 'NuGetFilesystemDevelopmentPackagePath'
  'RepositoryNuGetFilesystemQualityAssurancePackageNameConfigRootKey'                            = 'NuGetFilesystemQualityAssurancePackage'
  'RepositoryNuGetFilesystemQualityAssurancePackagePathConfigRootKey'                            = 'NuGetFilesystemQualityAssurancePackagePath'
  'RepositoryNuGetFilesystemProductionPackageNameConfigRootKey'                                  = 'NuGetFilesystemProductionPackage'
  'RepositoryNuGetFilesystemProductionPackagePathConfigRootKey'                                  = 'NuGetFilesystemProductionPackagePath'
  'RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageNameConfigRootKey'                  = 'NuGetQualityAssuranceWebServerDevelopmentPackage'
  'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageNameConfigRootKey'             = 'NuGetQualityAssuranceWebServerQualityAssurancePackage'
  'RepositoryNuGetQualityAssuranceWebServerProductionPackageNameConfigRootKey'                   = 'NuGetQualityAssuranceWebServerProductionPackage'
  'RepositoryNuGetProductionWebServerDevelopmentPackageNameConfigRootKey'                        = 'NuGetProductionWebServerDevelopmentPackage'
  'RepositoryNuGetProductionWebServerQualityAssurancePackageNameConfigRootKey'                   = 'NuGetProductionWebServerQualityAssurancePackage'
  'RepositoryNuGetProductionWebServerProductionPackageNameConfigRootKey'                         = 'NuGetProductionWebServerProductionPackage'

  # The name of the repository for Packages that are in PowershellGet format
  'RepositoryPowershellGetFilesystemDevelopmentPackageNameConfigRootKey'                         = 'PowershellGetFilesystemDevelopmentPackage'
  'RepositoryPowershellGetFilesystemDevelopmentPackagePathConfigRootKey'                         = 'PowershellGetFilesystemDevelopmentPackagePath'
  'RepositoryPowershellGetFilesystemQualityAssurancePackageNameConfigRootKey'                    = 'PowershellGetFilesystemQualityAssurancePackage'
  'RepositoryPowershellGetFilesystemQualityAssurancePackagePathConfigRootKey'                    = 'PowershellGetFilesystemQualityAssurancePackagePath'
  'RepositoryPowershellGetFilesystemProductionPackageNameConfigRootKey'                          = 'PowershellGetFilesystemProductionPackage'
  'RepositoryPowershellGetFilesystemProductionPackagePathConfigRootKey'                          = 'PowershellGetFilesystemProductionPackagePath'
  'RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageNameConfigRootKey'          = 'PowershellGetQualityAssuranceWebServerDevelopmentPackage'
  'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageNameConfigRootKey'     = 'PowershellGetQualityAssuranceWebServerQualityAssurancePackage'
  'RepositoryPowershellGetQualityAssuranceWebServerProductionPackageNameConfigRootKey'           = 'PowershellGetQualityAssuranceWebServerProductionPackage'
  'RepositoryPowershellGetProductionWebServerDevelopmentPackageNameConfigRootKey'                = 'PowershellGetProductionWebServerDevelopmentPackage'
  'RepositoryPowershellGetProductionWebServerQualityAssurancePackageNameConfigRootKey'           = 'PowershellGetProductionWebServerQualityAssurancePackage'
  'RepositoryPowershellGetProductionWebServerProductionPackageNameConfigRootKey'                 = 'PowershellGetProductionWebServerProductionPackage'

  # The name of the repository for Packages that are in Chocolatey format
  'RepositoryChocolateyFilesystemDevelopmentPackageNameConfigRootKey'                            = 'ChocolateyFilesystemDevelopmentPackage'
  'RepositoryChocolateyFilesystemDevelopmentPackagePathConfigRootKey'                            = 'ChocolateyFilesystemDevelopmentPackagePath'
  'RepositoryChocolateyFilesystemQualityAssurancePackageNameConfigRootKey'                       = 'ChocolateyFilesystemQualityAssurancePackage'
  'RepositoryChocolateyFilesystemQualityAssurancePackagePathConfigRootKey'                       = 'ChocolateyFilesystemQualityAssurancePackagePath'
  'RepositoryChocolateyFilesystemProductionPackageNameConfigRootKey'                             = 'ChocolateyFilesystemProductionPackage'
  'RepositoryChocolateyFilesystemProductionPackagePathConfigRootKey'                             = 'ChocolateyFilesystemProductionPackagePath'
  'RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageNameConfigRootKey'             = 'ChocolateyQualityAssuranceWebServerDevelopmentPackage'
  'RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageNameConfigRootKey'        = 'ChocolateyQualityAssuranceWebServerQualityAssurancePackage'
  'RepositoryChocolateyQualityAssuranceWebServerProductionPackageNameConfigRootKey'              = 'ChocolateyQualityAssuranceWebServerProductionPackage'
  'RepositoryChocolateyProductionWebServerDevelopmentPackageNameConfigRootKey'                   = 'ChocolateyProductionWebServerDevelopmentPackage'
  'RepositoryChocolateyProductionWebServerQualityAssurancePackageNameConfigRootKey'              = 'ChocolateyProductionWebServerQualityAssurancePackage'
  'RepositoryChocolateyProductionWebServerProductionPackageNameConfigRootKey'                    = 'ChocolateyProductionWebServerProductionPackage'

  # URI details for web-based repositories
  # URI Details for NuGet Web Server
  'RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageProtocolConfigRootKey'              = 'NuGetQualityAssuranceWebServerDevelopmentPackageProtocol'
  'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey'         = 'NuGetQualityAssuranceWebServerQualityAssurancePackageProtocol'
  'RepositoryNuGetQualityAssuranceWebServerProductionPackageProtocolConfigRootKey'               = 'NuGetQualityAssuranceWebServerProductionPackageProtocol'
  'RepositoryNuGetProductionWebServerDevelopmentPackageProtocolConfigRootKey'                    = 'NuGetProductionWebServerDevelopmentPackageProtocol'
  'RepositoryNuGetProductionWebServerQualityAssurancePackageProtocolConfigRootKey'               = 'NuGetProductionWebServerQualityAssurancePackageProtocol'
  'RepositoryNuGetProductionWebServerProductionPackageProtocolConfigRootKey'                     = 'NuGetProductionWebServerProductionPackageProtocol'
  'RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageServerConfigRootKey'                = 'NuGetQualityAssuranceWebServerDevelopmentPackageServer'
  'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey'           = 'NuGetQualityAssuranceWebServerQualityAssurancePackageServer'
  'RepositoryNuGetQualityAssuranceWebServerProductionPackageServerConfigRootKey'                 = 'NuGetQualityAssuranceWebServerProductionPackageServer'
  'RepositoryNuGetProductionWebServerDevelopmentPackageServerConfigRootKey'                      = 'NuGetProductionWebServerDevelopmentPackageServer'
  'RepositoryNuGetProductionWebServerQualityAssurancePackageServerConfigRootKey'                 = 'NuGetProductionWebServerQualityAssurancePackageServer'
  'RepositoryNuGetProductionWebServerProductionPackageServerConfigRootKey'                       = 'NuGetProductionWebServerProductionPackageServer'
  'RepositoryNuGetQualityAssuranceWebServerDevelopmentPackagePortConfigRootKey'                  = 'NuGetQualityAssuranceWebServerDevelopmentPackagePort'
  'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey'             = 'NuGetQualityAssuranceWebServerQualityAssurancePackagePort'
  'RepositoryNuGetQualityAssuranceWebServerProductionPackagePortConfigRootKey'                   = 'NuGetQualityAssuranceWebServerProductionPackagePort'
  'RepositoryNuGetProductionWebServerDevelopmentPackagePortConfigRootKey'                        = 'NuGetProductionWebServerDevelopmentPackagePort'
  'RepositoryNuGetProductionWebServerQualityAssurancePackagePortConfigRootKey'                   = 'NuGetProductionWebServerQualityAssurancePackagePort'
  'RepositoryNuGetProductionWebServerProductionPackagePortConfigRootKey'                         = 'NuGetProductionWebServerProductionPackagePort'
  # URIs For NuGetWebServer
  'RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageURIConfigRootKey'                   = 'RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageURI'
  'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey'              = 'RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageURI'
  'RepositoryNuGetQualityAssuranceWebServerProductionPackageURIConfigRootKey'                    = 'RepositoryNuGetQualityAssuranceWebServerProductionPackageURI'
  'RepositoryNuGetProductionWebServerDevelopmentPackageURIConfigRootKey'                         = 'RepositoryNuGetProductionWebServerDevelopmentPackageURI'
  'RepositoryNuGetProductionWebServerQualityAssurancePackageURIConfigRootKey'                    = 'RepositoryNuGetProductionWebServerQualityAssurancePackageURI'
  'RepositoryNuGetProductionWebServerProductionPackageURIConfigRootKey'                          = 'RepositoryNuGetProductionWebServerProductionPackageURI'

  # URI Details for PowershellGet Web Server
  'RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageProtocolConfigRootKey'      = 'PowershellGetQualityAssuranceWebServerDevelopmentPackageProtocol'
  'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey' = 'PowershellGetQualityAssuranceWebServerQualityAssurancePackageProtocol'
  'RepositoryPowershellGetQualityAssuranceWebServerProductionPackageProtocolConfigRootKey'       = 'PowershellGetQualityAssuranceWebServerProductionPackageProtocol'
  'RepositoryPowershellGetProductionWebServerDevelopmentPackageProtocolConfigRootKey'            = 'PowershellGetProductionWebServerDevelopmentPackageProtocol'
  'RepositoryPowershellGetProductionWebServerQualityAssurancePackageProtocolConfigRootKey'       = 'PowershellGetProductionWebServerQualityAssurancePackageProtocol'
  'RepositoryPowershellGetProductionWebServerProductionPackageProtocolConfigRootKey'             = 'PowershellGetProductionWebServerProductionPackageProtocol'
  'RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageServerConfigRootKey'        = 'PowershellGetQualityAssuranceWebServerDevelopmentPackageServer'
  'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey'   = 'PowershellGetQualityAssuranceWebServerQualityAssurancePackageServer'
  'RepositoryPowershellGetQualityAssuranceWebServerProductionPackageServerConfigRootKey'         = 'PowershellGetQualityAssuranceWebServerProductionPackageServer'
  'RepositoryPowershellGetProductionWebServerDevelopmentPackageServerConfigRootKey'              = 'PowershellGetProductionWebServerDevelopmentPackageServer'
  'RepositoryPowershellGetProductionWebServerQualityAssurancePackageServerConfigRootKey'         = 'PowershellGetProductionWebServerQualityAssurancePackageServer'
  'RepositoryPowershellGetProductionWebServerProductionPackageServerConfigRootKey'               = 'PowershellGetProductionWebServerProductionPackageServer'
  'RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackagePortConfigRootKey'          = 'PowershellGetQualityAssuranceWebServerDevelopmentPackagePort'
  'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey'     = 'PowershellGetQualityAssuranceWebServerQualityAssurancePackagePort'
  'RepositoryPowershellGetQualityAssuranceWebServerProductionPackagePortConfigRootKey'           = 'PowershellGetQualityAssuranceWebServerProductionPackagePort'
  'RepositoryPowershellGetProductionWebServerDevelopmentPackagePortConfigRootKey'                = 'PowershellGetProductionWebServerDevelopmentPackagePort'
  'RepositoryPowershellGetProductionWebServerQualityAssurancePackagePortConfigRootKey'           = 'PowershellGetProductionWebServerQualityAssurancePackagePort'
  'RepositoryPowershellGetProductionWebServerProductionPackagePortConfigRootKey'                 = 'PowershellGetProductionWebServerProductionPackagePort'
  # URIs For PowershellGetWebServer
  'RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageURIConfigRootKey'           = 'RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageURI'
  'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey'      = 'RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageURI'
  'RepositoryPowershellGetQualityAssuranceWebServerProductionPackageURIConfigRootKey'            = 'RepositoryPowershellGetQualityAssuranceWebServerProductionPackageURI'
  'RepositoryPowershellGetProductionWebServerDevelopmentPackageURIConfigRootKey'                 = 'RepositoryPowershellGetProductionWebServerDevelopmentPackageURI'
  'RepositoryPowershellGetProductionWebServerQualityAssurancePackageURIConfigRootKey'            = 'RepositoryPowershellGetProductionWebServerQualityAssurancePackageURI'
  'RepositoryPowershellGetProductionWebServerProductionPackageURIConfigRootKey'                  = 'RepositoryPowershellGetProductionWebServerProductionPackageURI'

  # URI Details for Chocolatey Web Server
  'RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageProtocolConfigRootKey'         = 'ChocolateyQualityAssuranceWebServerDevelopmentPackageProtocol'
  'RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageProtocolConfigRootKey'    = 'ChocolateyQualityAssuranceWebServerQualityAssurancePackageProtocol'
  'RepositoryChocolateyQualityAssuranceWebServerProductionPackageProtocolConfigRootKey'          = 'ChocolateyQualityAssuranceWebServerProductionPackageProtocol'
  'RepositoryChocolateyProductionWebServerDevelopmentPackageProtocolConfigRootKey'               = 'ChocolateyProductionWebServerDevelopmentPackageProtocol'
  'RepositoryChocolateyProductionWebServerQualityAssurancePackageProtocolConfigRootKey'          = 'ChocolateyProductionWebServerQualityAssurancePackageProtocol'
  'RepositoryChocolateyProductionWebServerProductionPackageProtocolConfigRootKey'                = 'ChocolateyProductionWebServerProductionPackageProtocol'
  'RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageServerConfigRootKey'           = 'ChocolateyQualityAssuranceWebServerDevelopmentPackageServer'
  'RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageServerConfigRootKey'      = 'ChocolateyQualityAssuranceWebServerQualityAssurancePackageServer'
  'RepositoryChocolateyQualityAssuranceWebServerProductionPackageServerConfigRootKey'            = 'ChocolateyQualityAssuranceWebServerProductionPackageServer'
  'RepositoryChocolateyProductionWebServerDevelopmentPackageServerConfigRootKey'                 = 'ChocolateyProductionWebServerDevelopmentPackageServer'
  'RepositoryChocolateyProductionWebServerQualityAssurancePackageServerConfigRootKey'            = 'ChocolateyProductionWebServerQualityAssurancePackageServer'
  'RepositoryChocolateyProductionWebServerProductionPackageServerConfigRootKey'                  = 'ChocolateyProductionWebServerProductionPackageServer'
  'RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackagePortConfigRootKey'             = 'ChocolateyQualityAssuranceWebServerDevelopmentPackagePort'
  'RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackagePortConfigRootKey'        = 'ChocolateyQualityAssuranceWebServerQualityAssurancePackagePort'
  'RepositoryChocolateyQualityAssuranceWebServerProductionPackagePortConfigRootKey'              = 'ChocolateyQualityAssuranceWebServerProductionPackagePort'
  'RepositoryChocolateyProductionWebServerDevelopmentPackagePortConfigRootKey'                   = 'ChocolateyProductionWebServerDevelopmentPackagePort'
  'RepositoryChocolateyProductionWebServerQualityAssurancePackagePortConfigRootKey'              = 'ChocolateyProductionWebServerQualityAssurancePackagePort'
  'RepositoryChocolateyProductionWebServerProductionPackagePortConfigRootKey'                    = 'ChocolateyProductionWebServerProductionPackagePort'
  # URIs For ChocolateyWebServer
  'RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageURIConfigRootKey'              = 'RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageURI'
  'RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey'         = 'RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageURI'
  'RepositoryChocolateyQualityAssuranceWebServerProductionPackageURIConfigRootKey'               = 'RepositoryChocolateyQualityAssuranceWebServerProductionPackageURI'
  'RepositoryChocolateyProductionWebServerDevelopmentPackageURIConfigRootKey'                    = 'RepositoryChocolateyProductionWebServerDevelopmentPackageURI'
  'RepositoryChocolateyProductionWebServerQualityAssurancePackageURIConfigRootKey'               = 'RepositoryChocolateyProductionWebServerQualityAssurancePackageURI'
  'RepositoryChocolateyProductionWebServerProductionPackageURIConfigRootKey'                     = 'RepositoryChocolateyProductionWebServerProductionPackageURI'

  # The collection that lists all powershell package repositories
  'PackageRepositoriesCollectionConfigRootKey'                                                   = 'PackageRepositoriesCollection'

  # Where all things Security and Secrets related are stored
  'SECURE_CLOUD_BASE_PATHConfigRootKey'                                                          = 'SECURE_CLOUD_BASE_PATH'

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

  #  These define where a Certificte Authority (CA) keeps the records of the CSRs it is given, and a copy of each Certificate it creates and signs
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
  'SecureVaultBasePathConfigRootKey'                                                             = 'SecureVaultBasePath'
  'SecretVaultKeyFilePathConfigRootKey'                                                          = 'SecretVaultKeyFilePath'
  'SecretVaultEncryptedPasswordFilePathConfigRootKey'                                            = 'SecretVaultEncryptedPasswordFilePath'
  #'EncryptedMasterPasswordsPathConfigRootKey'                                          = 'EncryptedMasterPasswordsPath'
  # 'ATAPUtilitiesMasterPasswordsPathConfigRootKey'                                      = 'ATAPUtilitiesMasterPasswordsPath'
  'SecretVaultExtensionModuleNameConfigRootKey'                                                  = 'SecretExtensionVaultModuleName'
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

