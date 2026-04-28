# AI assisted using Powershell.instructions.md as guidelines

<#
.SYNOPSIS
Initializes $global:configRootKeys with the core set of string-constant key names.

.DESCRIPTION
Creates $global:configRootKeys as a new hashtable and populates it with the canonical
set of key-name constants used throughout the ATAP ecosystem to look up values from
$global:settings.

This function must be the first ConfigRootKeys fragment to run. All other Add-*ConfigRootKeys
functions depend on $global:configRootKeys already existing.

.OUTPUTS
None. Creates and populates $global:configRootKeys as a side effect.

.EXAMPLE
Set-CoreConfigRootKeys

Initializes $global:configRootKeys with all core key constants.

.EXAMPLE
Set-CoreConfigRootKeys -WhatIf

Shows that $global:configRootKeys would be initialized without doing so.

.NOTES
AI assisted using Powershell.instructions.md as guidelines

.LINK
https://github.com/BillHertzing/ATAP.Utilities
#>

function Set-CoreConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [Alias()]
  [OutputType([void])]
  param ()

  begin {
    $fn = 'Set-CoreConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
  }

  process {
    try {
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Initialize with core key constants')) {
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
          # ProGet Package Repository software settings
          # ProGetHostConfigRootKey and URI component keys moved to ATAP.IAC ProGet fragment
          # ToDo: evaluate whether ProGetBaseUri* keys should also move to ATAP.IAC ProGet fragment
          'ProGetBaseUriBuilderConfigRootKey'                                                            = 'ProGetBaseUriBuilder'
          'ProGetBaseUriConfigRootKey'                                                                   = 'ProGetBaseUri'
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
          # Allows Wireshark and other applications to capture the SSL Keys pre-negotiation
          'SSLKEYLOGFILEConfigRootKey'                                                                   = 'SSLKEYLOGFILE'
          # Location of Python interpreter
          'PythonInterpretersBaseDirectoryConfigRootKey'                                                 = 'PythonInterpretersBaseDirectory'
          'PythonInterpretersInstallDirectoryConfigRootKey'                                              = 'PythonInterpretersInstallDirectory'
          'PythonExePathConfigRootKey'                                                                   = 'PythonExePath'
          # Manim animation renderer executable path
          'ManimExePathConfigRootKey'                                                                    = 'MANIM_EXE_PATH'
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
          # CICDHosts configuration keys — used by Jenkins Controller and agents
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
          # Structure of subdirectories generated during PowerShell module packaging
          'TemporaryPowershellModulePackagingDirectoryConfigRootKey'                                     = 'TemporaryPowershellModulePackagingDirectory'
          'TemporaryPowershellModulePackagingSourceDirectoryConfigRootKey'                               = 'TemporaryPowershellModulePackagingSourceDirectory'
          'TemporaryPowershellModulePackagingIntermediateDirectoryConfigRootKey'                         = 'TemporaryPowershellModulePackagingIntermediateDirectory'
          'TemporaryPowershellModulePackagingDistributionPackagesDirectoryConfigRootKey'                 = 'TemporaryPowershellModulePackagingDistributionPackagesDirectory'
          'GeneratedRelativePathConfigRootKey'                                                           = 'GeneratedSubdirectory'
          'GeneratedTestResultsPathConfigRootKey'                                                        = 'GeneratedTestResultsSubdirectory'
          'GeneratedUnitTestResultsPathConfigRootKey'                                                    = 'GeneratedUnitTestResultsSubdirectory'
          'GeneratedIntegrationTestResultsPathConfigRootKey'                                             = 'GeneratedIntegrationTestResultsSubdirectory'
          'GeneratedTestCoverageResultsPathConfigRootKey'                                                = 'GeneratedTestCoverageREsultsSubdirectory'
          'GeneratedDocumentationDestinationPathConfigRootKey'                                           = 'GeneratedDocumentationSubdirectory'
          'GeneratedStaticSiteDocumentationDestinationPathConfigRootKey'                                 = 'GeneratedStaticSiteSubdirectory'
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
          # Related to PKI Certificate creation and storage
          'SecureCertificatesBasePathConfigRootKey'                                                      = 'SecureCertificatesBasePath'
          'SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey'                                 = 'SecureCertificatesEncryptionKeyPassPhraseFilesPath'
          'SecureCertificatesEncryptedKeysPathConfigRootKey'                                             = 'SecureCertificatesEncryptedKeysPath'
          'SecureCertificatesCertificateRequestsPathConfigRootKey'                                       = 'SecureCertificatesCertificateRequestsPath'
          'SecureCertificatesCertificatesPathConfigRootKey'                                              = 'SecureCertificatesCertificatesPath'
          'SecureCertificatesDataEncryptionCertificatesPathConfigRootKey'                                = 'SecureCertificatesDataEncryptionCertificatesPath'
          'SecureCertificatesOpenSSLConfigsPathConfigRootKey'                                            = 'SecureCertificatesOpenSSLConfigsPath'
          'SecureCertificatesCrossReferenceFilenameConfigRootKey'                                        = 'SecureCertificatesCrossReferenceDNFile'
          'SecureCertificatesSigningCertificatesPathConfigRootKey'                                       = 'SecureCertificatesSigningCertificatesPath'
          'SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey'           = 'SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePath'
          # Certificate-related filename base names (used as -BaseFileName parameter)
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
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message '$global:configRootKeys initialized with core key constants.'
      }
    } catch {
      $errorMessage = "Unhandled error in $fn. Exception: $($_.Exception.Message)"
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
      throw
    } finally {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving process block in $fn"
    }
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
