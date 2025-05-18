# ToDo comment based help
$global:configRootKeys = @{
  # IAC for Hosts having the C: drive as the systemdrive
  'SYSTEMDRIVEConfigRootKey'                                                                               = 'C:'
  'ProgramFilesConfigRootKey'                                                                              = 'ProgramFiles'
  'ProgramDataConfigRootKey'                                                                               = 'ProgramData'
  'ATAPUtilitiesVersionConfigRootKey'                                                                      = 'ATAPUtilitiesVersion'
  'ENVIRONMENTConfigRootKey'                                                                               = 'Environment'
  'IsElevatedConfigRootKey'                                                                                = 'IsElevated'
  'CloudBasePathConfigRootKey'                                                                             = 'CloudBasePath'
  'GoogleDriveBasePathConfigRootKey'                                                                       = 'GoogleDriveBasePath'
  # Dropbox settings
  'DropboxBasePathConfigRootKey'                                                                           = 'DropboxBasePath'
  'DropboxAccessTokenConfigRootKey'                                                                        = 'DropboxAccessToken'
  # OneDrive Settings
  'OneDriveBasePathConfigRootKey'                                                                          = 'OneDriveBasePath'
  'FastTempBasePathConfigRootKey'                                                                          = 'FAST_TEMP_BASE_PATH'
  'BigTempBasePathConfigRootKey'                                                                           = 'BIG_TEMP_BASE_PATH'
  'SecureTempBasePathConfigRootKey'                                                                        = 'SECURE_TEMP_BASE_PATH'
  'ChocolateyPackagesConfigRootKey'                                                                        = 'ChocolateyPackages'
  # Ditto Clipboard Manager Settings
  'DittoDBPathConfigRootKey'                                                                               = 'DittoDBPath'
  # Erlang settings
  'ErlangHomeDirConfigRootKey'                                                                             = 'ErlangHomeDir'
  # GIT settings
  'GIT_CONFIG_GLOBALConfigRootKey'                                                                         = 'GIT_CONFIG_GLOBAL'
  'GitExePathConfigRootKey'                                                                                = 'GitExePath'
  # JAVA interpreter executable settings
  'JavaInstallDirRelativeSubdirectoryConfigRootKey'                                                        = 'JavaInstallDirRelativeSubdirectory'
  'JavaExePathConfigRootKey'                                                                               = 'JavaExePath'
  # Jenkins CI/CD configuration keys
  'JenkinsNodeRolesConfigRootKey'                                                                          = 'JenkinsNodeRoles'
  # Jenkins Environment Variables
  # JENKINS_HOME applies only to jenkins Controller nodes
  'JENKINS_HOMEConfigRootKey'                                                                              = 'JENKINS_HOME'
  # These Jenkins Environment Variables are used to access a Jenkins Controller and Authenticate
  'JENKINS_URLConfigRootKey'                                                                               = 'JENKINS_URL'
  'JENKINS_USER_IDConfigRootKey'                                                                           = 'JENKINS_USER_ID'
  'JENKINS_API_TOKENConfigRootKey'                                                                         = 'JENKINS_API_TOKEN'
  # ChatGPT settings
  'CHATGPT_URLConfigRootKey'                                                                               = 'CHATGPT_URL'
  'CHATGPT_USER_IDConfigRootKey'                                                                           = 'CHATGPT_USER_ID'
  'CHATGPT_API_TOKENConfigRootKey'                                                                         = 'CHATGPT_API_TOKEN'

  'ChocolateyInstallDirConfigRootKey'                                                                      = 'ChocolateyInstall'
  'ChocolateyBinDirConfigRootKey'                                                                          = 'ChocolateyBinDir'
  'ChocolateyLibDirConfigRootKey'                                                                          = 'ChocolateyLibDir'
  'ChocolateyCacheLocationConfigRootKey'                                                                   = 'ChocolateyCacheLocation'
  'GraphvizExePathConfigRootKey'                                                                           = 'GraphvizExePath'
  'PackageDropPathsConfigRootKey'                                                                          = 'PackageDropPaths'
  'BuildImageFromPlantUMLConfigRootKey'                                                                    = 'BuildImageFromPlantUMPowershellCmdlet'
  'MSBuildExePathConfigRootKey'                                                                            = 'MSBuildExePath'
  'xUnitConsoleTestRunnerPackageConfigRootKey'                                                             = 'xUnitConsoleTestRunnerPackage'
  'xUnitJenkinsPluginPackageConfigRootKey'                                                                 = 'xUnitJenkinsPluginPackage'
  'DocFXExePathConfigRootKey'                                                                              = 'DocFXExePath'
  'DotnetExePathConfigRootKey'                                                                             = 'DotnetExePath'
  'PlantUMLJarPathConfigRootKey'                                                                           = 'PlantUMLJarPath'
  'PlantUmlClassDiagramGeneratorExePathConfigRootKey'                                                      = 'PlantUmlClassDiagramGeneratorExePath'
  'BuildImageFromPlantUMLPowershellCmdletNameConfigRootKey'                                                = 'BuildImageFromPlantUMLPowershellCmdletName'
  'SQLServerPSModulePathsConfigRootKey'                                                                    = 'SQLServerPSModulePaths'
  'SQLServerConnectionStringConfigRootKey'                                                                 = 'SQLServerConnectionString'
  'WindowsUnitTestParameterListConfigRootKey'                                                              = 'WindowsUnitTestParameterList'
  'WindowsUnitTestParameterPathConfigRootKey'                                                              = 'WindowsUnitTestParameterPath'
  'PSModulePathConfigRootKey'                                                                              = 'PSModulePath'
  'FLYWAY_PASSWORDConfigRootKey'                                                                           = 'FLYWAY_PASSWORD'
  'FLYWAY_USERConfigRootKey'                                                                               = 'FLYWAY_USER'
  'FLYWAY_LOCATIONSConfigRootKey'                                                                          = 'FLYWAY_LOCATIONS'
  'FLYWAY_URLConfigRootKey'                                                                                = 'FLYWAY_URL'
  'FP__projectNameConfigRootKey'                                                                           = 'FP__projectName'
  'FP__projectDescriptionConfigRootKey'                                                                    = 'FP__projectDescription'
  'CommonJarsBasePathConfigRootKey'                                                                        = 'CommonJarsBasePath'

  #  # Allows Wireshark and other applications to capture the SSL Keys pre-negotiation, so HTTPS SSL traffic can be decrypted
  'SSLKEYLOGFILEConfigRootKey'                                                                             = 'SSLKEYLOGFILE'
  # Location of Python interpreter
  'PythonInterpretersBaseDirectoryConfigRootKey'                                                           = 'PythonInterpretersBaseDirectory'
  'PythonInterpretersInstallDirectoryConfigRootKey'                                                        = 'PythonInterpretersInstallDirectory'
  'PythonExePathConfigRootKey'                                                                             = 'PythonExePath'

  # related to the Hydrus-Network application
  'HYDRUS_ACCESS_KEYConfigRootKey'                                                                         = 'HydrusAccessKey'
  'HydrusAPIServerConfigRootKey'                                                                           = 'HydrusAPIServer'
  'HydrusAPIProtocolConfigRootKey'                                                                         = 'HydrusAPIProtocol'
  'HydrusAPIPortConfigRootKey'                                                                             = 'HydrusAPIPort'

  # related to the Get-FileMetadata cmdlet
  'FileMetadataBlockSizeConfigRootKey'                                                                     = 'FileMetadataBlockSize'
  'GetFileSignatureAsMetadataConfigRootKey'                                                                = 'GetFileSignatureAsMetadata'

  # Used by ansible
  'ansible_remote_tmpConfigRootKey'                                                                        = 'ansible_remote_tmp'
  'ansible_become_userConfigRootKey'                                                                       = 'ansible_become_user'
  'AnsibleAllowPrereleaseConfigRootKey'                                                                    = 'AnsibleAllowPrelease'

  # CICDHosts configuration keys
  # Used by Jenkins Controller and agents
  'JenkinsControllerServiceAccountConfigRootKey'                                                           = 'JenkinsControllerServiceAccount'
  'JenkinsControllerServiceAccountPasswordKeyConfigRootKey'                                                = 'JenkinsControllerServiceAccountPasswordKey'
  'JenkinsControllerServiceAccountFullnameConfigRootKey'                                                   = 'JenkinsControllerServiceAccountFullname'
  'JenkinsControllerServiceAccountDescriptionConfigRootKey'                                                = 'JenkinsControllerServiceAccountDescription'
  'JenkinsControllerServiceAccountUserHomeDirectoryConfigRootKey'                                          = 'JenkinsControllerServiceAccountUserHomeDirectory'
  'JenkinsControllerServiceAccountPowershellDesktopProfileSourcePathConfigRootKey'                         = 'JenkinsControllerServiceAccountPowershellDesktopProfileSourcePath'
  'JenkinsControllerServiceAccountPowershellCoreProfileSourcePathConfigRootKey'                            = 'JenkinsControllerServiceAccountPowershellCoreProfileSourcePath'
  'JenkinsAgentServiceAccountConfigRootKey'                                                                = 'JenkinsAgentServiceAccount'
  'JenkinsAgentServiceAccountPasswordKeyConfigRootKey'                                                     = 'JenkinsAgentServiceAccountPasswordKey'
  'JenkinsAgentServiceAccountFullnameConfigRootKey'                                                        = 'JenkinsAgentServiceAccountFullname'
  'JenkinsAgentServiceAccountDescriptionConfigRootKey'                                                     = 'JenkinsAgentServiceAccountDescription'
  'JenkinsAgentServiceAccountUserHomeDirectoryConfigRootKey'                                               = 'JenkinsAgentServiceAccountUserHomeDirectory'
  'JenkinsAgentServiceAccountPowershellDesktopProfileSourcePathConfigRootKey'                              = 'JenkinsAgentServiceAccountPowershellDesktopProfileSourcePath'
  'JenkinsAgentServiceAccountPowershellCoreProfileSourcePathConfigRootKey'                                 = 'JenkinsAgentServiceAccountPowershellCoreProfileSourcePath'

  # WinSW for Jenkins agent
  'WinSWPublicURLConfigRootKey'                                                                            = 'WinSWPublicURL'
  'WinSWInternalDestinationFilenameConfigRootKey'                                                          = 'WinSWInternalDestinationFilename'
  'WinSWInternalDestinationBaseDirectoryConfigRootKey'                                                     = 'WinSWInternalDestinationBaseDirectory'
  'WinSWInternalDestinationVersionConfigRootKey'                                                           = 'WinSWInternalDestinationVersion'
  'WinSWInternalDestinationDirectoryConfigRootKey'                                                         = 'WinSWInternalDestinationDirectory'
  'WinSWInternalDestinationPathConfigRootKey'                                                              = 'WinSWInternalDestinationPath'

  # Computer roles (used in the JenkinsNodeRoles)
  'WindowsCodeBuildConfigRootKey'                                                                          = 'WindowsCodeBuild'
  'WindowsUnitTestConfigRootKey'                                                                           = 'WindowsUnitTest'
  'WindowsIntegrationTestConfigRootKey'                                                                    = 'WindowIntegrationTest'
  'WindowsDocumentationBuildConfigRootKey'                                                                 = 'WindowsDocumentationBuild'

  # Structure of the subdirectories generated during the process of building a Powershell Module for public distribution
  # The directory name where files used by the module/package creation and generated by the developer build and CI/CD process build are placed
  'TemporaryPowershellModulePackagingDirectoryConfigRootKey'                                               = 'TemporaryPowershellModulePackagingDirectory'
  # The directory name where module source files are placed by the module/package creation process during a developer build and CI/CD process build
  'TemporaryPowershellModulePackagingSourceDirectoryConfigRootKey'                                         = 'TemporaryPowershellModulePackagingSourceDirectory'
  # The directory name where the generated intermediate package files are placed by the module/package creation process during a developer build and CI/CD process build
  'TemporaryPowershellModulePackagingIntermediateDirectoryConfigRootKey'                                   = 'TemporaryPowershellModulePackagingIntermediateDirectory'
  # The directory name where the generated finished package files are placed by the module/package creation process during a developer build and CI/CD process build
  'TemporaryPowershellModulePackagingDistributionPackagesDirectoryConfigRootKey'                           = 'TemporaryPowershellModulePackagingDistributionPackagesDirectory'
  'GeneratedRelativePathConfigRootKey'                                                                     = 'GeneratedSubdirectory'

  # The subdirectory name under a repository root where test results generated by the developer build and CI/CD process build are placed
  'GeneratedTestResultsPathConfigRootKey'                                                                  = 'GeneratedTestResultsSubdirectory'
  # The subdirectory name under a repository root where Unit test results generated by the developer build and CI/CD process build are placed
  'GeneratedUnitTestResultsPathConfigRootKey'                                                              = 'GeneratedUnitTestResultsSubdirectory'
  # The subdirectory name under a repository root where Integration test results generated by the developer build and CI/CD process build are placed
  'GeneratedIntegrationTestResultsPathConfigRootKey'                                                       = 'GeneratedIntegrationTestResultsSubdirectory'
  # The subdirectory name under a repository root where Integration test results generated by the developer build and CI/CD process build are placed
  'GeneratedTestCoverageResultsPathConfigRootKey'                                                          = 'GeneratedTestCoverageREsultsSubdirectory'

  # The subdirectory name under a repository root where documentation generated by the developer build and CI/CD process build are placed
  'GeneratedDocumentationDestinationPathConfigRootKey'                                                     = 'GeneratedDocumentationSubdirectory'
  # The subdirectory name under a repository root where static site documentation generated by the developer build and CI/CD process build are placed
  'GeneratedStaticSiteDocumentationDestinationPathConfigRootKey'                                           = 'GeneratedStaticSiteSubdirectory'

  # PackageRepository Uris for Packaging, Deploying, Delivering, Updating
  # All Package repositories that use a filesystem can use the default source and drop locations, or specify a full custom paths
  'RepositoryFileSystemPackageSourceLocationBaseDirectoryDefaultConfigRootKey'                             = 'RepositoryFileSystemPackageSourceLocationBasePathDefault'
  'RepositoryFileSystemPackageDropLocationBasePathDefaultConfigRootKey'                                    = 'RepositoryFileSystemPackageDropLocationBasePathDefault'


  # PackageRepository Uri subkeys are formed as
  # 'PackageRepository' + ('External' |'Internal' ) + ('Released' | 'Prerelease') + ('Filesystem' | 'NuGet' | 'PowershellGet' | 'ChocolateyGet') + ('Production' | 'QualityAssurance') + 'Package' + ('Pull' | 'Push') + 'Uri'
  # External Pull Uris
  'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriConfigRootKey'                            = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUri'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriConfigRootKey'                      = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUri'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriConfigRootKey'                    = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUri'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriConfigRootKey'              = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUri'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriConfigRootKey'                    = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUri'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriConfigRootKey'              = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUri'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriConfigRootKey'                          = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUri'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriConfigRootKey'                    = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUri'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriConfigRootKey'                  = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUri'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriConfigRootKey'            = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUri'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriConfigRootKey'                  = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUri'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriConfigRootKey'            = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUri'
  # Internal Pull Uris
  'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriConfigRootKey'                            = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUri'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriConfigRootKey'                      = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUri'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriConfigRootKey'                    = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUri'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriConfigRootKey'              = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUri'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriConfigRootKey'                    = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUri'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriConfigRootKey'              = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUri'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriConfigRootKey'                          = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUri'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriConfigRootKey'                    = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUri'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriConfigRootKey'                  = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUri'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriConfigRootKey'            = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUri'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriConfigRootKey'                  = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUri'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriConfigRootKey'            = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUri'
  # External Push Uris
  'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriConfigRootKey'                            = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUri'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriConfigRootKey'                      = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUri'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriConfigRootKey'                    = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUri'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriConfigRootKey'              = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUri'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriConfigRootKey'                    = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUri'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriConfigRootKey'              = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUri'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriConfigRootKey'                          = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUri'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriConfigRootKey'                    = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUri'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriConfigRootKey'                  = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUri'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriConfigRootKey'            = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUri'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriConfigRootKey'                  = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUri'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriConfigRootKey'            = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUri'
  # Internal Push Uris
  'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriConfigRootKey'                            = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUri'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriConfigRootKey'                      = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUri'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriConfigRootKey'                    = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUri'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriConfigRootKey'              = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUri'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriConfigRootKey'                    = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUri'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriConfigRootKey'              = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUri'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriConfigRootKey'                          = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUri'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriConfigRootKey'                    = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUri'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriConfigRootKey'                  = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUri'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriConfigRootKey'            = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUri'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriConfigRootKey'                  = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUri'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriConfigRootKey'            = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUri'

  # The individual components that make up the pull and push Uris for PackageRepository Http Servers
  # Every push or pull Uri is made up of 'Protocol' + 'Server' + 'Port' + 'Path' + 'QueryString'. Path defaults to '/' and QueryString defaults to ''
  # Pull Uri individual components
  # External Pull Uri components
  'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriProtocolConfigRootKey'                    = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriProtocol'
  'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriServerConfigRootKey'                      = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriServer'
  'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriPortConfigRootKey'                        = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriPort'
  'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriPathConfigRootKey'                        = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriPath'
  'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriQueryStringConfigRootKey'                 = 'PackageRepositoryExternalReleasedNuGetProductionPackagePullUriQueryString'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriProtocolConfigRootKey'              = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriServerConfigRootKey'                = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriPortConfigRootKey'                  = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriPathConfigRootKey'                  = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriQueryStringConfigRootKey'           = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePullUriQueryString'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriProtocolConfigRootKey'            = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriProtocol'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriServerConfigRootKey'              = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriServer'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriPortConfigRootKey'                = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriPort'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriPathConfigRootKey'                = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriPath'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriQueryString'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriProtocolConfigRootKey'      = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriServerConfigRootKey'        = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriPortConfigRootKey'          = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriPathConfigRootKey'          = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriQueryStringConfigRootKey'   = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePullUriQueryString'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriProtocolConfigRootKey'            = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriProtocol'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriServerConfigRootKey'              = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriServer'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriPortConfigRootKey'                = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriPort'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriPathConfigRootKey'                = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriPath'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriQueryString'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriProtocolConfigRootKey'      = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriServerConfigRootKey'        = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriPortConfigRootKey'          = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriPathConfigRootKey'          = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriQueryStringConfigRootKey'   = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePullUriQueryString'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriProtocolConfigRootKey'                  = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriProtocol'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriServerConfigRootKey'                    = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriServer'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriPortConfigRootKey'                      = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriPort'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriPathConfigRootKey'                      = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriPath'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriQueryStringConfigRootKey'               = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriQueryString'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriProtocolConfigRootKey'            = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriServerConfigRootKey'              = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriPortConfigRootKey'                = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriPathConfigRootKey'                = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriQueryString'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriProtocolConfigRootKey'          = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriProtocol'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriServerConfigRootKey'            = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriServer'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriPortConfigRootKey'              = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriPort'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriPathConfigRootKey'              = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriPath'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriQueryStringConfigRootKey'       = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriQueryString'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriProtocolConfigRootKey'    = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriServerConfigRootKey'      = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriPortConfigRootKey'        = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriPathConfigRootKey'        = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriQueryStringConfigRootKey' = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriQueryString'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriProtocolConfigRootKey'          = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriProtocol'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriServerConfigRootKey'            = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriServer'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriPortConfigRootKey'              = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriPort'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriPathConfigRootKey'              = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriPath'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriQueryStringConfigRootKey'       = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriQueryString'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriProtocolConfigRootKey'    = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriServerConfigRootKey'      = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPortConfigRootKey'        = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPathConfigRootKey'        = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriQueryStringConfigRootKey' = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriQueryString'
  # External Push Uri components
  'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriProtocolConfigRootKey'                    = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriProtocol'
  'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriServerConfigRootKey'                      = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriServer'
  'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriPortConfigRootKey'                        = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriPort'
  'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriPathConfigRootKey'                        = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriPath'
  'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriQueryStringConfigRootKey'                 = 'PackageRepositoryExternalReleasedNuGetProductionPackagePushUriQueryString'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriProtocolConfigRootKey'              = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriServerConfigRootKey'                = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriPortConfigRootKey'                  = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriPathConfigRootKey'                  = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriQueryStringConfigRootKey'           = 'PackageRepositoryExternalReleasedNuGetQualityAssurancePackagePushUriQueryString'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriProtocolConfigRootKey'            = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriProtocol'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriServerConfigRootKey'              = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriServer'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriPortConfigRootKey'                = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriPort'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriPathConfigRootKey'                = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriPath'
  'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalReleasedPowershellGetProductionPackagePushUriQueryString'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriProtocolConfigRootKey'      = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriServerConfigRootKey'        = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriPortConfigRootKey'          = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriPathConfigRootKey'          = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriQueryStringConfigRootKey'   = 'PackageRepositoryExternalReleasedPowershellGetQualityAssurancePackagePushUriQueryString'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriProtocolConfigRootKey'            = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriProtocol'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriServerConfigRootKey'              = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriServer'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriPortConfigRootKey'                = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriPort'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriPathConfigRootKey'                = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriPath'
  'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalReleasedChocolateyGetProductionPackagePushUriQueryString'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriProtocolConfigRootKey'      = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriServerConfigRootKey'        = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriPortConfigRootKey'          = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriPathConfigRootKey'          = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriQueryStringConfigRootKey'   = 'PackageRepositoryExternalReleasedChocolateyGetQualityAssurancePackagePushUriQueryString'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriProtocolConfigRootKey'                  = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriProtocol'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriServerConfigRootKey'                    = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriServer'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriPortConfigRootKey'                      = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriPort'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriPathConfigRootKey'                      = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriPath'
  'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriQueryStringConfigRootKey'               = 'PackageRepositoryExternalPrereleaseNuGetProductionPackagePushUriQueryString'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriProtocolConfigRootKey'            = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriServerConfigRootKey'              = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriPortConfigRootKey'                = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriPathConfigRootKey'                = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePushUriQueryString'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriProtocolConfigRootKey'          = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriProtocol'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriServerConfigRootKey'            = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriServer'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriPortConfigRootKey'              = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriPort'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriPathConfigRootKey'              = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriPath'
  'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriQueryStringConfigRootKey'       = 'PackageRepositoryExternalPrereleasePowershellGetProductionPackagePushUriQueryString'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriProtocolConfigRootKey'    = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriServerConfigRootKey'      = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriPortConfigRootKey'        = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriPathConfigRootKey'        = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriQueryStringConfigRootKey' = 'PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePushUriQueryString'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriProtocolConfigRootKey'          = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriProtocol'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriServerConfigRootKey'            = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriServer'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriPortConfigRootKey'              = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriPort'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriPathConfigRootKey'              = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriPath'
  'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriQueryStringConfigRootKey'       = 'PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePushUriQueryString'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriProtocolConfigRootKey'    = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriServerConfigRootKey'      = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPortConfigRootKey'        = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPathConfigRootKey'        = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriQueryStringConfigRootKey' = 'PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePushUriQueryString'
  # Internal Pull Uri components
  'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriProtocolConfigRootKey'                    = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriProtocol'
  'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriServerConfigRootKey'                      = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriServer'
  'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriPortConfigRootKey'                        = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriPort'
  'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriPathConfigRootKey'                        = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriPath'
  'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriQueryStringConfigRootKey'                 = 'PackageRepositoryInternalReleasedNuGetProductionPackagePullUriQueryString'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriProtocolConfigRootKey'              = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriServerConfigRootKey'                = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriPortConfigRootKey'                  = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriPathConfigRootKey'                  = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriQueryStringConfigRootKey'           = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriQueryString'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriProtocolConfigRootKey'            = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriProtocol'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriServerConfigRootKey'              = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriServer'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriPortConfigRootKey'                = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriPort'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriPathConfigRootKey'                = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriPath'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriQueryString'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriProtocolConfigRootKey'      = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriServerConfigRootKey'        = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriPortConfigRootKey'          = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriPathConfigRootKey'          = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriQueryStringConfigRootKey'   = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriQueryString'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriProtocolConfigRootKey'            = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriProtocol'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriServerConfigRootKey'              = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriServer'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriPortConfigRootKey'                = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriPort'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriPathConfigRootKey'                = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriPath'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriQueryString'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriProtocolConfigRootKey'      = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriServerConfigRootKey'        = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriPortConfigRootKey'          = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriPathConfigRootKey'          = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriQueryStringConfigRootKey'   = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriQueryString'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriProtocolConfigRootKey'                  = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriProtocol'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriServerConfigRootKey'                    = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriServer'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriPortConfigRootKey'                      = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriPort'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriPathConfigRootKey'                      = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriPath'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriQueryStringConfigRootKey'               = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePullUriQueryString'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriProtocolConfigRootKey'            = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriServerConfigRootKey'              = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriPortConfigRootKey'                = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriPathConfigRootKey'                = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePullUriQueryString'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriProtocolConfigRootKey'          = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriProtocol'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriServerConfigRootKey'            = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriServer'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriPortConfigRootKey'              = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriPort'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriPathConfigRootKey'              = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriPath'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriQueryStringConfigRootKey'       = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePullUriQueryString'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriProtocolConfigRootKey'    = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriServerConfigRootKey'      = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriPortConfigRootKey'        = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriPathConfigRootKey'        = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriQueryStringConfigRootKey' = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePullUriQueryString'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriProtocolConfigRootKey'          = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriProtocol'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriServerConfigRootKey'            = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriServer'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriPortConfigRootKey'              = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriPort'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriPathConfigRootKey'              = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriPath'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriQueryStringConfigRootKey'       = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePullUriQueryString'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriProtocolConfigRootKey'    = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriProtocol'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriServerConfigRootKey'      = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriServer'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPortConfigRootKey'        = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPort'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPathConfigRootKey'        = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriPath'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriQueryStringConfigRootKey' = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePullUriQueryString'
  # Internal Push Uri components
  'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriProtocolConfigRootKey'                    = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriProtocol'
  'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriServerConfigRootKey'                      = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriServer'
  'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriPortConfigRootKey'                        = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriPort'
  'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriPathConfigRootKey'                        = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriPath'
  'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriQueryStringConfigRootKey'                 = 'PackageRepositoryInternalReleasedNuGetProductionPackagePushUriQueryString'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriProtocolConfigRootKey'              = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriServerConfigRootKey'                = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriPortConfigRootKey'                  = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriPathConfigRootKey'                  = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriQueryStringConfigRootKey'           = 'PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePushUriQueryString'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriProtocolConfigRootKey'            = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriProtocol'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriServerConfigRootKey'              = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriServer'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriPortConfigRootKey'                = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriPort'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriPathConfigRootKey'                = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriPath'
  'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalReleasedPowershellGetProductionPackagePushUriQueryString'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriProtocolConfigRootKey'      = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriServerConfigRootKey'        = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriPortConfigRootKey'          = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriPathConfigRootKey'          = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriQueryStringConfigRootKey'   = 'PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePushUriQueryString'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriProtocolConfigRootKey'            = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriProtocol'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriServerConfigRootKey'              = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriServer'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriPortConfigRootKey'                = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriPort'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriPathConfigRootKey'                = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriPath'
  'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalReleasedChocolateyGetProductionPackagePushUriQueryString'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriProtocolConfigRootKey'      = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriServerConfigRootKey'        = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriPortConfigRootKey'          = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriPathConfigRootKey'          = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriQueryStringConfigRootKey'   = 'PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePushUriQueryString'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriProtocolConfigRootKey'                  = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriProtocol'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriServerConfigRootKey'                    = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriServer'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriPortConfigRootKey'                      = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriPort'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriPathConfigRootKey'                      = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriPath'
  'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriQueryStringConfigRootKey'               = 'PackageRepositoryInternalPrereleaseNuGetProductionPackagePushUriQueryString'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriProtocolConfigRootKey'            = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriServerConfigRootKey'              = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriPortConfigRootKey'                = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriPathConfigRootKey'                = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriQueryStringConfigRootKey'         = 'PackageRepositoryInternalPrereleaseNuGetQualityAssurancePackagePushUriQueryString'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriProtocolConfigRootKey'          = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriProtocol'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriServerConfigRootKey'            = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriServer'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriPortConfigRootKey'              = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriPort'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriPathConfigRootKey'              = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriPath'
  'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriQueryStringConfigRootKey'       = 'PackageRepositoryInternalPrereleasePowershellGetProductionPackagePushUriQueryString'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriProtocolConfigRootKey'    = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriServerConfigRootKey'      = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriPortConfigRootKey'        = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriPathConfigRootKey'        = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriQueryStringConfigRootKey' = 'PackageRepositoryInternalPrereleasePowershellGetQualityAssurancePackagePushUriQueryString'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriProtocolConfigRootKey'          = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriProtocol'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriServerConfigRootKey'            = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriServer'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriPortConfigRootKey'              = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriPort'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriPathConfigRootKey'              = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriPath'
  'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriQueryStringConfigRootKey'       = 'PackageRepositoryInternalPrereleaseChocolateyGetProductionPackagePushUriQueryString'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriProtocolConfigRootKey'    = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriProtocol'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriServerConfigRootKey'      = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriServer'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPortConfigRootKey'        = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPort'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPathConfigRootKey'        = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriPath'
  'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriQueryStringConfigRootKey' = 'PackageRepositoryInternalPrereleaseChocolateyGetQualityAssurancePackagePushUriQueryString'

  # The collection that lists all powershell package repositories
  'PackageRepositoriesCollectionConfigRootKey'                                                             = 'PackageRepositoriesCollection'

  # Where all things Security and Secrets related are stored
  'SECURE_CLOUD_BASE_PATHConfigRootKey'                                                                    = 'SECURE_CLOUD_BASE_PATH'

  # Powershell credentials for user/host pairs
  'SECURE_CLOUD_CREDENTIALS_PATHConfigRootKey'                                                             = 'SECURE_CLOUD_CREDENTIALS_PATH'

  # related to the Hashicorp Vault installation and operations
  'VAULT_ADDRConfigRootKey'                                                                                = 'VAULT_ADDR'
  'VAULT_TOKENConfigRootKey'                                                                               = 'VAULT_TOKEN'
  'VAULT_CACERTConfigRootKey'                                                                              = 'VAULT_CACERT'
  'VaultUnsealKeyConfigRootKey'                                                                            = 'VaultUnsealKey'
  'VaultRootTokenConfigRootKey'                                                                            = 'VaultRootToken'

  # OpenSSL Environment variables
  'OPENSSL_HOMEConfigRootKey'                                                                              = 'OPENSSL_HOME'
  'OPENSSL_CONFConfigRootKey'                                                                              = 'OPENSSL_CONF'
  'RANDFILEConfigRootKey'                                                                                  = 'RANDFILE'

  # Subdirectory where all files security related are kept
  # Related to PKI Certificate creation and storage
  'SecureCertificatesBasePathConfigRootKey'                                                                = 'SecureCertificatesBasePath'
  'SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey'                                           = 'SecureCertificatesEncryptionKeyPassPhraseFilesPath'
  'SecureCertificatesEncryptedKeysPathConfigRootKey'                                                       = 'SecureCertificatesEncryptedKeysPath'
  'SecureCertificatesCertificateRequestsPathConfigRootKey'                                                 = 'SecureCertificatesCertificateRequestsPath'
  'SecureCertificatesCertificatesPathConfigRootKey'                                                        = 'SecureCertificatesCertificatesPath'
  'SecureCertificatesDataEncryptionCertificatesPathConfigRootKey'                                          = 'SecureCertificatesDataEncryptionCertificatesPath'
  # Use this if special purpose openSSL configuration files are needed
  'SecureCertificatesOpenSSLConfigsPathConfigRootKey'                                                      = 'SecureCertificatesOpenSSLConfigsPath'
  # Use this if obfuscation of file names is desired
  'SecureCertificatesCrossReferenceFilenameConfigRootKey'                                                  = 'SecureCertificatesCrossReferenceDNFile'

  #  These define where a Certificate Authority (CA) keeps the records of the CSRs it is given, and a copy of each Certificate it creates and signs
  'SecureCertificatesSigningCertificatesPathConfigRootKey'                                                 = 'SecureCertificatesSigningCertificatesPath'
  #'SecureCertificatesSigningCertificatesPrivateKeysRelativePathConfigRootKey' = 'SecureCertificatesSigningCertificatesPrivateKeysRelativePath'
  #'SecureCertificatesSigningCertificatesNewCertificatesRelativePathConfigRootKey' ='SecureCertificatesSigningCertificatesNewCertificatesRelativePath'
  'SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey'                     = 'SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePath'
  #'SecureCertificatesSigningCertificatesSerialNumberRelativePathConfigRootKey' ='SecureCertificatesSigningCertificatesSerialNumberRelativePath'

  # These define the latter portion of certificate-related filename (used as the parameter -BaseFileName)
  'SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey'                                            = 'SecureCertificatesCAPassPhraseFileBaseFileName'
  'SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey'                                       = 'SecureCertificatesCAEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesCACertificateBaseFileNameConfigRootKey'                                               = 'SecureCertificatesCACertificateBaseFileName'
  'SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey'                                     = 'SecureCertificatesSSLServerPassPhraseFileBaseFileName'
  'SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey'                                = 'SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesSSLServerCertificateRequestBaseFileNameConfigRootKey'                                 = 'SecureCertificatesSSLServerCertificateRequestBaseFileName'
  'SecureCertificatesSSLServerCertificateBaseFileNameConfigRootKey'                                        = 'SecureCertificatesSSLServerCertificateBaseFileName'
  'SecureCertificatesCodeSigningPassPhraseFileBaseFileNameConfigRootKey'                                   = 'SecureCertificatesCodeSigningPassPhraseFileBaseFileName'
  'SecureCertificatesCodeSigningEncryptedPrivateKeyBaseFileNameConfigRootKey'                              = 'SecureCertificatesCodeSigningEncryptedPrivateKeyBaseFileName'
  'SecureCertificatesCodeSigningCertificateRequestBaseFileNameConfigRootKey'                               = 'SecureCertificatesCodeSigningCertificateRequestBaseFileName'
  'SecureCertificatesCodeSigningCertificateBaseFileNameConfigRootKey'                                      = 'SecureCertificatesCodeSigningCertificateBaseFileName'

  # SecretsManagement
  'SecretVaultBaseDirectoryConfigRootKey'                                                                  = 'SecureVaultBasePath'
  'SecretVaultEncryptionKeyFilePathConfigRootKey'                                                          = 'SecretVaultEncryptionKeyFilePath'
  'SecretVaultEncryptedPasswordFilePathConfigRootKey'                                                      = 'SecretVaultEncryptedPasswordFilePath'
  'SecretVaultModuleNameConfigRootKey'                                                                     = 'SecretVaultModuleName'
  'SecretVaultNameConfigRootKey'                                                                           = 'SecretVaultName'
  'SecretVaultDescriptionConfigRootKey'                                                                    = 'SecretVaultDescription'
  'SecretVaultKeySizeIntConfigRootKey'                                                                     = 'SecretVaultKeySizeInt'
  'SecretVaultPasswordTimeoutConfigRootKey'                                                                = 'SecretVaultPasswordTimeout'
  'SecretVaultPathToKeePassDBConfigRootKey'                                                                = 'SecretVaultPathToKeePassDB'

  # Locations for things that are needed in case of disaster
  'DisasterRecoveryPathConfigRootKey'                                                                      = 'DisasterRecoveryPath'
  'DisasterRecoveryBackupPathConfigRootKey'                                                                = 'DisasterRecoveryBackupPath'

  # Container (Machine, VM, Docker) Roles
  'DeveloperComputerRoleConfigRootKey'                                                                     = 'DeveloperComputer'
  'DocumentationComputerRoleConfigRootKey'                                                                 = 'DocumentationComputer'
  'TestingComputerRoleConfigRootKey'                                                                       = 'TestingComputer'
  'CICDComputerRoleConfigRootKey'                                                                          = 'CICDComputer'
  'DocFXComputerRoleConfigRootKey'                                                                         = 'DocFXComputer'
  'WebServerComputerRoleConfigRootKey'                                                                     = 'WebServerComputer'
  'JenkinsControllerComputerRoleConfigRootKey'                                                             = 'JenkinsControllerComputer'
  'JenkinsAgentComputerRoleConfigRootKey'                                                                  = 'JenkinsAgentComputer'
  'MSSQLServerComputerRoleConfigRootKey'                                                                   = 'MSSQLServerComputer'
  'PlantUMLComputerRoleConfigRootKey'                                                                      = 'PlantUMLComputer'
  'CertificateServerComputerRoleConfigRootKey'                                                             = 'CertificateServerComputer'

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

