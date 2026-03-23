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
  # Perplexity settings
  'PERPLEXITY_API_KEYConfigRootKey'                                                              = 'PERPLEXITY_API_KEY'
  # Syncfusion settings
  'SYNCFUSION_API_KEYConfigRootKey'                                                              = 'SYNCFUSION_API_KEY'
  # Context7 settings
  'CONTEXT7_API_KEYConfigRootKey'                                                                = 'CONTEXT7_API_KEY'
  ###################################################
  ## ProGet Package Manager ConfigRootKeys — Phase 1
  ## Drop-in replacement for the ProGet section of the configRootKeys hashtable.
  ## Phase 1: 8 combined feeds (no push/pull split).
  ## Phase 2: Uncomment the -Push keys to add push feed entries.
  ###################################################

  # ── ProGet Server ──────────────────────────────────────────────────────
  'ProGetHostConfigRootKey'                                                                      = 'ProGetHost'
  'ProGetServiceExePathConfigRootKey'                                                            = 'ProGetServiceExePath'
  'ProGetServiceConfigPathConfigRootKey'                                                         = 'ProGetServiceConfigPath'
  'ProGetAdminUriSchemeConfigRootKey'                                                            = 'ProGetAdminUriScheme'
  'ProGetAdminUriHostConfigRootKey'                                                              = 'ProGetAdminUriHost'
  'ProGetAdminUriPortConfigRootKey'                                                              = 'ProGetAdminUriPort'
  'ProGetBaseUrlConfigRootKey'                                                                   = 'ProGetBaseUrl'
  'PGUTIL_SOURCEConfigRootKey'                                                                   = 'PGUTIL_SOURCE'

  # ── ProGet API Keys ────────────────────────────────────────────────────
  'ProGetAdminApiKeyConfigRootKey'                                                               = 'PROGET_ADMIN_API_TOKEN'
  'ProGetBuildMasterApiKeyConfigRootKey'                                                         = 'PROGET_BUILDMASTER_KEY'
  # Phase 2 per-feed API keys (uncomment when push/pull feeds are created):
  # 'ProGetApiKeyNuGetExperimentalPushConfigRootKey'                                             = 'PROGET_APIKEY_NUGET_EXPERIMENTAL_PUSH'
  # 'ProGetApiKeyNuGetExperimentalPullConfigRootKey'                                             = 'PROGET_APIKEY_NUGET_EXPERIMENTAL_PULL'
  # 'ProGetApiKeyNuGetDevelopmentPushConfigRootKey'                                              = 'PROGET_APIKEY_NUGET_DEVELOPMENT_PUSH'
  # 'ProGetApiKeyNuGetDevelopmentPullConfigRootKey'                                              = 'PROGET_APIKEY_NUGET_DEVELOPMENT_PULL'
  # 'ProGetApiKeyNuGetTestingPushConfigRootKey'                                                  = 'PROGET_APIKEY_NUGET_TESTING_PUSH'
  # 'ProGetApiKeyNuGetTestingPullConfigRootKey'                                                  = 'PROGET_APIKEY_NUGET_TESTING_PULL'
  # 'ProGetApiKeyNuGetProductionPushConfigRootKey'                                               = 'PROGET_APIKEY_NUGET_PRODUCTION_PUSH'
  # 'ProGetApiKeyNuGetProductionPullConfigRootKey'                                               = 'PROGET_APIKEY_NUGET_PRODUCTION_PULL'
  # 'ProGetApiKeyPowerShellExperimentalPushConfigRootKey'                                        = 'PROGET_APIKEY_POWERSHELL_EXPERIMENTAL_PUSH'
  # 'ProGetApiKeyPowerShellExperimentalPullConfigRootKey'                                        = 'PROGET_APIKEY_POWERSHELL_EXPERIMENTAL_PULL'
  # 'ProGetApiKeyPowerShellDevelopmentPushConfigRootKey'                                         = 'PROGET_APIKEY_POWERSHELL_DEVELOPMENT_PUSH'
  # 'ProGetApiKeyPowerShellDevelopmentPullConfigRootKey'                                         = 'PROGET_APIKEY_POWERSHELL_DEVELOPMENT_PULL'
  # 'ProGetApiKeyPowerShellTestingPushConfigRootKey'                                             = 'PROGET_APIKEY_POWERSHELL_TESTING_PUSH'
  # 'ProGetApiKeyPowerShellTestingPullConfigRootKey'                                             = 'PROGET_APIKEY_POWERSHELL_TESTING_PULL'
  # 'ProGetApiKeyPowerShellProductionPushConfigRootKey'                                          = 'PROGET_APIKEY_POWERSHELL_PRODUCTION_PUSH'
  # 'ProGetApiKeyPowerShellProductionPullConfigRootKey'                                          = 'PROGET_APIKEY_POWERSHELL_PRODUCTION_PULL'

  # ── ProGet Connectors ──────────────────────────────────────────────────
  'ProGetConnectorNuGetOrgConfigRootKey'                                                         = 'ProGetConnectorNuGetOrg'
  'ProGetConnectorPSGalleryConfigRootKey'                                                        = 'ProGetConnectorPSGallery'
  'ProGetConnectorChocolateyOrgConfigRootKey'                                                    = 'ProGetConnectorChocolateyOrg'

  # ── Feed Collection & Promotion ────────────────────────────────────────
  'ProGetFeedCollectionConfigRootKey'                                                            = 'ProGetFeedCollection'
  'ProGetPromotionTierOrderConfigRootKey'                                                        = 'ProGetPromotionTierOrder'

  # ══════════════════════════════════════════════════════════════════════
  #  NuGet Feeds — Phase 1 (combined push/pull per tier)
  # ══════════════════════════════════════════════════════════════════════

  # ── nuget-experimental ─────────────────────────────────────────────────
  'ProGetFeedNuGetExperimentalUriSchemeConfigRootKey'                                            = 'ProGetFeedNuGetExperimentalUriScheme'
  'ProGetFeedNuGetExperimentalUriHostConfigRootKey'                                              = 'ProGetFeedNuGetExperimentalUriHost'
  'ProGetFeedNuGetExperimentalUriPortConfigRootKey'                                              = 'ProGetFeedNuGetExperimentalUriPort'
  'ProGetFeedNuGetExperimentalUriPathConfigRootKey'                                              = 'ProGetFeedNuGetExperimentalUriPath'
  'ProGetFeedNuGetExperimentalUriQueryStringConfigRootKey'                                       = 'ProGetFeedNuGetExperimentalUriQueryString'
  'ProGetFeedNuGetExperimentalUriConfigRootKey'                                                  = 'ProGetFeedNuGetExperimentalUri'
  'ProGetFeedNuGetExperimentalFeedNameConfigRootKey'                                             = 'ProGetFeedNuGetExperimentalFeedName'
  'ProGetFeedNuGetExperimentalFeedTypeConfigRootKey'                                             = 'ProGetFeedNuGetExperimentalFeedType'
  'ProGetFeedNuGetExperimentalApiKeyNameConfigRootKey'                                           = 'ProGetFeedNuGetExperimentalApiKeyName'
  'ProGetFeedNuGetExperimentalFeedConfigRootKey'                                                 = 'ProGetFeedNuGetExperimental'

  # ── nuget-development ──────────────────────────────────────────────────
  'ProGetFeedNuGetDevelopmentUriSchemeConfigRootKey'                                             = 'ProGetFeedNuGetDevelopmentUriScheme'
  'ProGetFeedNuGetDevelopmentUriHostConfigRootKey'                                               = 'ProGetFeedNuGetDevelopmentUriHost'
  'ProGetFeedNuGetDevelopmentUriPortConfigRootKey'                                               = 'ProGetFeedNuGetDevelopmentUriPort'
  'ProGetFeedNuGetDevelopmentUriPathConfigRootKey'                                               = 'ProGetFeedNuGetDevelopmentUriPath'
  'ProGetFeedNuGetDevelopmentUriQueryStringConfigRootKey'                                        = 'ProGetFeedNuGetDevelopmentUriQueryString'
  'ProGetFeedNuGetDevelopmentUriConfigRootKey'                                                   = 'ProGetFeedNuGetDevelopmentUri'
  'ProGetFeedNuGetDevelopmentFeedNameConfigRootKey'                                              = 'ProGetFeedNuGetDevelopmentFeedName'
  'ProGetFeedNuGetDevelopmentFeedTypeConfigRootKey'                                              = 'ProGetFeedNuGetDevelopmentFeedType'
  'ProGetFeedNuGetDevelopmentApiKeyNameConfigRootKey'                                            = 'ProGetFeedNuGetDevelopmentApiKeyName'
  'ProGetFeedNuGetDevelopmentFeedConfigRootKey'                                                  = 'ProGetFeedNuGetDevelopment'

  # ── nuget-testing ──────────────────────────────────────────────────────
  'ProGetFeedNuGetTestingUriSchemeConfigRootKey'                                                 = 'ProGetFeedNuGetTestingUriScheme'
  'ProGetFeedNuGetTestingUriHostConfigRootKey'                                                   = 'ProGetFeedNuGetTestingUriHost'
  'ProGetFeedNuGetTestingUriPortConfigRootKey'                                                   = 'ProGetFeedNuGetTestingUriPort'
  'ProGetFeedNuGetTestingUriPathConfigRootKey'                                                   = 'ProGetFeedNuGetTestingUriPath'
  'ProGetFeedNuGetTestingUriQueryStringConfigRootKey'                                            = 'ProGetFeedNuGetTestingUriQueryString'
  'ProGetFeedNuGetTestingUriConfigRootKey'                                                       = 'ProGetFeedNuGetTestingUri'
  'ProGetFeedNuGetTestingFeedNameConfigRootKey'                                                  = 'ProGetFeedNuGetTestingFeedName'
  'ProGetFeedNuGetTestingFeedTypeConfigRootKey'                                                  = 'ProGetFeedNuGetTestingFeedType'
  'ProGetFeedNuGetTestingApiKeyNameConfigRootKey'                                                = 'ProGetFeedNuGetTestingApiKeyName'
  'ProGetFeedNuGetTestingFeedConfigRootKey'                                                      = 'ProGetFeedNuGetTesting'

  # ── nuget-production ───────────────────────────────────────────────────
  'ProGetFeedNuGetProductionUriSchemeConfigRootKey'                                              = 'ProGetFeedNuGetProductionUriScheme'
  'ProGetFeedNuGetProductionUriHostConfigRootKey'                                                = 'ProGetFeedNuGetProductionUriHost'
  'ProGetFeedNuGetProductionUriPortConfigRootKey'                                                = 'ProGetFeedNuGetProductionUriPort'
  'ProGetFeedNuGetProductionUriPathConfigRootKey'                                                = 'ProGetFeedNuGetProductionUriPath'
  'ProGetFeedNuGetProductionUriQueryStringConfigRootKey'                                         = 'ProGetFeedNuGetProductionUriQueryString'
  'ProGetFeedNuGetProductionUriConfigRootKey'                                                    = 'ProGetFeedNuGetProductionUri'
  'ProGetFeedNuGetProductionFeedNameConfigRootKey'                                               = 'ProGetFeedNuGetProductionFeedName'
  'ProGetFeedNuGetProductionFeedTypeConfigRootKey'                                               = 'ProGetFeedNuGetProductionFeedType'
  'ProGetFeedNuGetProductionApiKeyNameConfigRootKey'                                             = 'ProGetFeedNuGetProductionApiKeyName'
  'ProGetFeedNuGetProductionFeedConfigRootKey'                                                   = 'ProGetFeedNuGetProduction'

  # ══════════════════════════════════════════════════════════════════════
  #  PowerShell Feeds — Phase 1 (combined push/pull per tier)
  # ══════════════════════════════════════════════════════════════════════

  # ── powershell-experimental ────────────────────────────────────────────
  'ProGetFeedPowerShellExperimentalUriSchemeConfigRootKey'                                       = 'ProGetFeedPowerShellExperimentalUriScheme'
  'ProGetFeedPowerShellExperimentalUriHostConfigRootKey'                                         = 'ProGetFeedPowerShellExperimentalUriHost'
  'ProGetFeedPowerShellExperimentalUriPortConfigRootKey'                                         = 'ProGetFeedPowerShellExperimentalUriPort'
  'ProGetFeedPowerShellExperimentalUriPathConfigRootKey'                                         = 'ProGetFeedPowerShellExperimentalUriPath'
  'ProGetFeedPowerShellExperimentalUriQueryStringConfigRootKey'                                  = 'ProGetFeedPowerShellExperimentalUriQueryString'
  'ProGetFeedPowerShellExperimentalUriConfigRootKey'                                             = 'ProGetFeedPowerShellExperimentalUri'
  'ProGetFeedPowerShellExperimentalFeedNameConfigRootKey'                                        = 'ProGetFeedPowerShellExperimentalFeedName'
  'ProGetFeedPowerShellExperimentalFeedTypeConfigRootKey'                                        = 'ProGetFeedPowerShellExperimentalFeedType'
  'ProGetFeedPowerShellExperimentalApiKeyNameConfigRootKey'                                      = 'ProGetFeedPowerShellExperimentalApiKeyName'
  'ProGetFeedPowerShellExperimentalFeedConfigRootKey'                                            = 'ProGetFeedPowerShellExperimental'

  # ── powershell-development ─────────────────────────────────────────────
  'ProGetFeedPowerShellDevelopmentUriSchemeConfigRootKey'                                        = 'ProGetFeedPowerShellDevelopmentUriScheme'
  'ProGetFeedPowerShellDevelopmentUriHostConfigRootKey'                                          = 'ProGetFeedPowerShellDevelopmentUriHost'
  'ProGetFeedPowerShellDevelopmentUriPortConfigRootKey'                                          = 'ProGetFeedPowerShellDevelopmentUriPort'
  'ProGetFeedPowerShellDevelopmentUriPathConfigRootKey'                                          = 'ProGetFeedPowerShellDevelopmentUriPath'
  'ProGetFeedPowerShellDevelopmentUriQueryStringConfigRootKey'                                   = 'ProGetFeedPowerShellDevelopmentUriQueryString'
  'ProGetFeedPowerShellDevelopmentUriConfigRootKey'                                              = 'ProGetFeedPowerShellDevelopmentUri'
  'ProGetFeedPowerShellDevelopmentFeedNameConfigRootKey'                                         = 'ProGetFeedPowerShellDevelopmentFeedName'
  'ProGetFeedPowerShellDevelopmentFeedTypeConfigRootKey'                                         = 'ProGetFeedPowerShellDevelopmentFeedType'
  'ProGetFeedPowerShellDevelopmentApiKeyNameConfigRootKey'                                       = 'ProGetFeedPowerShellDevelopmentApiKeyName'
  'ProGetFeedPowerShellDevelopmentFeedConfigRootKey'                                             = 'ProGetFeedPowerShellDevelopment'

  # ── powershell-testing ─────────────────────────────────────────────────
  'ProGetFeedPowerShellTestingUriSchemeConfigRootKey'                                            = 'ProGetFeedPowerShellTestingUriScheme'
  'ProGetFeedPowerShellTestingUriHostConfigRootKey'                                              = 'ProGetFeedPowerShellTestingUriHost'
  'ProGetFeedPowerShellTestingUriPortConfigRootKey'                                              = 'ProGetFeedPowerShellTestingUriPort'
  'ProGetFeedPowerShellTestingUriPathConfigRootKey'                                              = 'ProGetFeedPowerShellTestingUriPath'
  'ProGetFeedPowerShellTestingUriQueryStringConfigRootKey'                                       = 'ProGetFeedPowerShellTestingUriQueryString'
  'ProGetFeedPowerShellTestingUriConfigRootKey'                                                  = 'ProGetFeedPowerShellTestingUri'
  'ProGetFeedPowerShellTestingFeedNameConfigRootKey'                                             = 'ProGetFeedPowerShellTestingFeedName'
  'ProGetFeedPowerShellTestingFeedTypeConfigRootKey'                                             = 'ProGetFeedPowerShellTestingFeedType'
  'ProGetFeedPowerShellTestingApiKeyNameConfigRootKey'                                           = 'ProGetFeedPowerShellTestingApiKeyName'
  'ProGetFeedPowerShellTestingFeedConfigRootKey'                                                 = 'ProGetFeedPowerShellTesting'

  # ── powershell-production ──────────────────────────────────────────────
  'ProGetFeedPowerShellProductionUriSchemeConfigRootKey'                                         = 'ProGetFeedPowerShellProductionUriScheme'
  'ProGetFeedPowerShellProductionUriHostConfigRootKey'                                           = 'ProGetFeedPowerShellProductionUriHost'
  'ProGetFeedPowerShellProductionUriPortConfigRootKey'                                           = 'ProGetFeedPowerShellProductionUriPort'
  'ProGetFeedPowerShellProductionUriPathConfigRootKey'                                           = 'ProGetFeedPowerShellProductionUriPath'
  'ProGetFeedPowerShellProductionUriQueryStringConfigRootKey'                                    = 'ProGetFeedPowerShellProductionUriQueryString'
  'ProGetFeedPowerShellProductionUriConfigRootKey'                                               = 'ProGetFeedPowerShellProductionUri'
  'ProGetFeedPowerShellProductionFeedNameConfigRootKey'                                          = 'ProGetFeedPowerShellProductionFeedName'
  'ProGetFeedPowerShellProductionFeedTypeConfigRootKey'                                          = 'ProGetFeedPowerShellProductionFeedType'
  'ProGetFeedPowerShellProductionApiKeyNameConfigRootKey'                                        = 'ProGetFeedPowerShellProductionApiKeyName'
  'ProGetFeedPowerShellProductionFeedConfigRootKey'                                              = 'ProGetFeedPowerShellProduction'

  # ══════════════════════════════════════════════════════════════════════
  #  Chocolatey Feeds — DEFERRED (uncomment when Chocolatey packaging begins)
  #  Same pattern: ProGetFeedChocolatey{Tier}{Component}ConfigRootKey
  # ══════════════════════════════════════════════════════════════════════
  # 'ProGetFeedChocolateyExperimentalUriSchemeConfigRootKey'                                     = 'ProGetFeedChocolateyExperimentalUriScheme'
  # 'ProGetFeedChocolateyExperimentalUriHostConfigRootKey'                                       = 'ProGetFeedChocolateyExperimentalUriHost'
  # 'ProGetFeedChocolateyExperimentalUriPortConfigRootKey'                                       = 'ProGetFeedChocolateyExperimentalUriPort'
  # 'ProGetFeedChocolateyExperimentalUriPathConfigRootKey'                                       = 'ProGetFeedChocolateyExperimentalUriPath'
  # 'ProGetFeedChocolateyExperimentalUriQueryStringConfigRootKey'                                = 'ProGetFeedChocolateyExperimentalUriQueryString'
  # 'ProGetFeedChocolateyExperimentalUriConfigRootKey'                                           = 'ProGetFeedChocolateyExperimentalUri'
  # 'ProGetFeedChocolateyExperimentalFeedNameConfigRootKey'                                      = 'ProGetFeedChocolateyExperimentalFeedName'
  # 'ProGetFeedChocolateyExperimentalFeedTypeConfigRootKey'                                      = 'ProGetFeedChocolateyExperimentalFeedType'
  # 'ProGetFeedChocolateyExperimentalApiKeyNameConfigRootKey'                                    = 'ProGetFeedChocolateyExperimentalApiKeyName'
  # 'ProGetFeedChocolateyExperimentalFeedConfigRootKey'                                          = 'ProGetFeedChocolateyExperimental'
  # ... (repeat for development, testing, production)

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

  # used by the jenkins role that creates a ProGetPackageRepositoryProvider Service
  'ProGetPackageRepositoryProviderServiceAccountConfigRootKey'                                   = 'ProGetPackageRepositoryProviderServiceAccount'
  'ProGetPackageRepositoryProviderServiceAccountPasswordKeyConfigRootKey'                        = 'ProGetPackageRepositoryProviderServiceAccountPasswordKey'
  'ProGetPackageRepositoryProviderServiceAccountFullnameConfigRootKey'                           = 'ProGetPackageRepositoryProviderServiceAccountFullname'
  'ProGetPackageRepositoryProviderServiceAccountDescriptionConfigRootKey'                        = 'ProGetPackageRepositoryProviderServiceAccountDescription'
  'ProGetPackageRepositoryProviderServiceAccountUserHomeDirectoryConfigRootKey'                  = 'ProGetPackageRepositoryProviderServiceAccountUserHomeDirectory'
  'ProGetPackageRepositoryProviderServiceAccountPowershellDesktopProfileSourcePathConfigRootKey' = 'ProGetPackageRepositoryProviderServiceAccountPowershellDesktopProfileSourcePath'
  'ProGetPackageRepositoryProviderServiceAccountPowershellCoreProfileSourcePathConfigRootKey'    = 'ProGetPackageRepositoryProviderServiceAccountPowershellCoreProfileSourcePath'

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

  # Used by Bitwarden
  'BW_EMAILConfigRootKey'                                                                        = 'BW_EMAIL'
  'BW_APP_PASSWORDConfigRootKey'                                                                 = 'BW_APP_PASSWORD'
  'BW_MASTER_PASSWORDConfigRootKey'                                                              = 'BW_MASTER_PASSWORD'

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
  'SecretVaultDatabasesDirectoryConfigRootKey'                                                   = 'SecretVaultDatabasesPath'
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

