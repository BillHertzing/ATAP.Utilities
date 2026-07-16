# ═══════════════════════════════════════════════════════════════════════════
# ARCHIVED DRAFT — moved from ATAP.IAC repo root 2026-07-07 (Sprint 0012
# Task 12.46.d, PlanPowershellReorganization.md 3.a). NOT loaded by the module
# (archive\ is not dot-sourced by the .psm1). This is aspirational/draft code:
# contains 8 PowerShell parse errors (e.g. 'UIHosts'.'CICDHosts', $Swcf'sKey) and has never been executable in its committed form.
# Superseded by the module''s live functions (Get-AnsibleBuildoutInventory,
# Get-AnsibleCertificates, Get-HostSettings). Kept for design reference only.
# ═══════════════════════════════════════════════════════════════════════════
#   # Need additional arguments to specify that CChoco should be imported into all Powershell scripts that need to control Windows Features `import-module CChoco -scope Global`
#   # Need additional arguments to specify that DISM should be imported into all Powershell scripts that need to control Windows Features `import-module C:\Windows\System32\WindowsPowerShell\v1.0\Modules\DISM -scope Global`

function Get-AnsibleInventory {
    # Until the organizations 'infrastructure-as-code (IAC)' is stored in a vault, import the function from the organizations current IAC directory
    . $(Join-Path $([Environment]::GetFolderPath('MyDocuments')) 'GitHub' 'ATAP.IAC' 'Windows' 'HostSettings.ps1')
    $resourcesSourcePath = Join-Path 'C:' 'Dropbox' 'whertzing' 'GitHub' 'ATAP.IAC' 'Resources'
    $chocolateyPackageInfoSourcePath = Join-Path $resourcesSourcePath 'ApprovedChocolateyPackagesInfo.yml'
    $windowsFeaturesInfoSourcePath = Join-Path $resourcesSourcePath 'ApprovedWindowsFeaturesInfo.yml'
    $powershellModuleInfoSourcePath = Join-Path $resourcesSourcePath 'ApprovedPowershellModulesInfo.yml'
    $registrySettingsInfoSourcePath = Join-Path $resourcesSourcePath 'ApprovedRegistrySettingsInfo.yml'
    $nugetPackagesInfoSourcePath = Join-Path $resourcesSourcePath 'ApprovedNugetPackagesInfo.yml'
    $AnsibleRoleInfoSourcePath = Join-Path $resourcesSourcePath 'ApprovedAnsibleRolesInfo.yml'

    # ToDo: Steps needed to get past filesystem authorizations (credentials and group/role membership)
    $secureResourcesSourcePath = Join-Path $resourcesSourcePath 'security'
    $ANVaultSecretsSourcePath = Join-Path $secureResourcesSourcePath '.ANVaultATAPSecrets.yml'
    $ANVaultPasswordFileSourcePath = Join-Path $secureResourcesSourcePath '.ANVault_password_file.txt'
    $PSVaultSecretsVaultSourcePath = Join-Path $secureResourcesSourcePath '.PSVaultATAP_secrets.kdbx'
    $PSVaultPasswordFileSourcePath = Join-Path $secureResourcesSourcePath '.PSvault_password_file.txt'

    # Create the structure that holds the allowed names and versions of the components
    $SwCfgInfos = @{
        NuGetPackageInfos      = $null #ConvertFrom-Yaml $(Get-Content -Path $nugetPackagesInfoSourcePath -Raw )
        ChocolateyPackageInfos = ConvertFrom-Yaml $(Get-Content -Path $chocolateyPackageInfoSourcePath -Raw )
        PowershellModuleInfos  = ConvertFrom-Yaml $(Get-Content -Path $powershellModuleInfoSourcePath -Raw )
        RegistrySettingsInfos  = ConvertFrom-Yaml $(Get-Content -Path $registrySettingsInfoSourcePath -Raw )
        WindowsFeatureInfos    = ConvertFrom-Yaml $(Get-Content -Path $windowsFeaturesInfoSourcePath -Raw  )
        AnsibleRoleInfos       = ConvertFrom-Yaml $(Get-Content -Path $AnsibleRoleInfoSourcePath -Raw  )
    }

    $hostType1Template = [ordered]@{
        # The LifeCycle Value for the software in this host
        $global:configRootKeys['ENVIRONMENTConfigRootKey']         = 'production'
        # The values of the environment variable for SYSTEMDRIVE
        $global:configRootKeys['SYSTEMDRIVEConfigRootKey']         = 'C:/'
        # The values of the environment variables for PROGRAMFILES and for ProgramData
        $global:configRootKeys['PROGRAMFILESConfigRootKey']        = Join-Path $hostType1Template[ $global:configRootKeys['SYSTEMDRIVEConfigRootKey']] 'Program Files'
        $global:configRootKeys['PROGRAMDATAConfigRootKey']         = Join-Path $hostType1Template[ $global:configRootKeys['SYSTEMDRIVEConfigRootKey']] 'ProgramData'
        $global:configRootKeys['FastTempBasePathConfigRootKey']    = Join-Path $hostType1Template[ $global:configRootKeys['SYSTEMDRIVEConfigRootKey']] 'Temp' 'Fast'
        $global:configRootKeys['BigTempBasePathConfigRootKey']     = Join-Path $hostType1Template[ $global:configRootKeys['SYSTEMDRIVEConfigRootKey']] 'Temp' 'Big'
        $global:configRootKeys['ansible_become_userConfigRootKey'] = 'ansibleAdmin'
    }

    # Define every computer in the local shard of the organization's IT inventory
    $ansibleInventory = @{
        HostNames         = [ordered]@{
            'ncat016'   = @{
                Environment            = 'production'
                AnsibleGroupNames      = @('WindowsHosts', 'MonitoredWindowsHosts', 'UIHosts'.'CICDHosts', 'DeveloperHosts', 'BuildHosts', 'QualityAssuranceHosts', 'AVEditingHosts', 'Printing3DHosts', 'SocialMediaHosts', 'JenkinsControllerHosts', 'PKICertificationAuthorityHosts', 'ProGetPackageRepositoryProviderHosts')
                # ToDo: drivers that are HW specific for a host and are also GroupName dependent
                # additional Host-specific chocolatey packages, PowershellModuleNames, RegistrySettingsNames, WindowsFeatureNames ,
                ChocolateyPackageNames = @(, 'logitechgaming') # ToDO: make this both host HW-specific and also GamingHost specific
                # These settings start with one of the pre-defined computer types (having a set of disks and graphics and peripherals)
                #  and add any host-specific changes to any of the predefined settings
                Settings               = ($hostType1Template, @{
                        $global:configRootKeys['FastTempBasePathConfigRootKey']    = Join-Path 'D:' 'Temp' 'Fast'
                        $global:configRootKeys['BigTempBasePathConfigRootKey']     = Join-Path 'D:' 'Temp' 'Big'
                        $global:configRootKeys['ansible_become_userConfigRootKey'] = 'whertzing'
                    })
            }
            'ncat041'   = @{
                Environment       = 'QualityAssurance'
                AnsibleGroupNames = @('WindowsHosts', 'MonitoredWindowsHosts', 'UIHosts'.'CICDHosts', 'DeveloperHosts', 'BuildHosts', 'QualityAssuranceHosts', 'AVEditingHosts', 'Printing3DHosts', 'SocialMediaHosts', 'JenkinsControllerHosts', 'PKICertificationAuthorityHosts', 'ProGetPackageRepositoryProviderHosts')
                Settings          = ($hostType1Template, @{
                        # The LifeCycle Value for the software in this host
                        $global:configRootKeys['ENVIRONMENTConfigRootKey'] = 'QualityAssurance'
                    })
            }
            'ncat-ltb1' = @{
                Environment       = 'production'
                AnsibleGroupNames = @('WindowsHosts', 'MonitoredWindowsHosts', 'UIHosts'.'CICDHosts', 'DeveloperHosts', 'BuildHosts', 'QualityAssuranceHosts', 'AVEditingHosts', 'Printing3DHosts', 'SocialMediaHosts', 'JenkinsControllerHosts', 'PKICertificationAuthorityHosts', 'ProGetPackageRepositoryProviderHosts')
                Settings          = $hostType1Template
            }
            'ncat-ltjo' = @{
                Environment       = 'QualityAssurance'
                AnsibleGroupNames = @('WindowsHosts', 'MonitoredWindowsHosts', 'UIHosts'.'CICDHosts', 'DeveloperHosts', 'BuildHosts', 'QualityAssuranceHosts', 'AVEditingHosts', 'Printing3DHosts', 'SocialMediaHosts', 'JenkinsControllerHosts', 'PKICertificationAuthorityHosts', 'ProGetPackageRepositoryProviderHosts')
                Settings          = ($hostType1Template, @{
                        # The LifeCycle Value for the software in this host
                        $global:configRootKeys['ENVIRONMENTConfigRootKey'] = 'QualityAssurance'
                    })
            }
            'utat01'    = @{
                Environment       = 'production'
                AnsibleGroupNames = @('WindowsHosts', 'MonitoredWindowsHosts', 'UIHosts'.'CICDHosts', 'DeveloperHosts', 'BuildHosts', 'QualityAssuranceHosts', 'AVEditingHosts', 'Printing3DHosts', 'SocialMediaHosts', 'JenkinsControllerHosts', 'PKICertificationAuthorityHosts', 'ProGetPackageRepositoryProviderHosts')
                Settings          = ($hostType1Template, @{
                    })
            }
            'utat022'   = @{
                Environment            = 'production'
                AnsibleGroupNames      = @('WindowsHosts', 'MonitoredWindowsHosts', 'UIHosts'.'CICDHosts', 'DeveloperHosts', 'BuildHosts', 'QualityAssuranceHosts', 'AVEditingHosts', 'Printing3DHosts', 'SocialMediaHosts', 'JenkinsControllerHosts', 'PKICertificationAuthorityHosts', 'ProGetPackageRepositoryProviderHosts')
                # additional Host-specific chocolatey packages, PowershellModuleNames, RegistrySettingsNames, WindowsFeatureNames ,
                ChocolateyPackageNames = @(, 'nvidia-display-driver') # EVGA keyboard, mouse, pad, synapse drivers,
                Settings               = ($hostType1Template, @{
                        $global:configRootKeys['FastTempBasePathConfigRootKey'] = Join-Path 'D:' 'Temp'
                        $global:configRootKeys['BigTempBasePathConfigRootKey']  = Join-Path 'E:' 'Temp'
                    })
            }
        }
        # Settings are commented out currently, as all settings are currently made only at the host level
        AnsibleGroupNames = [ordered]@{ # ('AppDatabaseComputers', 'DatabaseMSSQLHosts', 'Linux' )
            WindowsHosts                         = @{
                ChocolateyPackageNames = @('7zip', 'bitwarden', 'bitwarden-cli', 'carbon', 'gpg4win') #  , 'vault', 'keepass'
                # ChocolateyPackageNames = @('7zip', 'bitwarden', 'carbon', 'Everything', 'es', 'gpg4win', 'keepass', 'nordvpn', 'nssm', 'powershell-core', 'vcredist-all') #  , 'vault'
                PowershellModuleNames  = @('Assert') # 'ComputerManagementDsc') # 'DISM', # Pester (for testing /validating a task worked)
                # PowershellModuleNames  = @('Assert', 'ChocolateyGet', 'NuGet', 'powershell-yaml', 'PackageManagement', 'PSResourceGet', 'PSDesiredStateConfiguration', 'PSDscResources', 'PSFramework', 'Microsoft.PowerShell.SecretManagement') # 'ComputerManagementDsc') # 'DISM', # Pester (for testing /validating a task worked)
                RegistrySettingsNames  = @('AssociateKDBXExtensionsWithKeePass')
                #RegistrySettingsNames  = @('DisableTelemetry', 'DisableGameDVR', 'AssociateKDBXExtensionsWithKeePass')
                WindowsFeatureNames    = @('RoleFeatureDefender', 'RoleFeatureSSH.Server', 'Microsoft-Windows-Subsystem-Linux')
                # This is the order in which roles are installed for this group. Role definitions are found in the  AnsibleRoleInfoDefault.yml file and are modified by the organization-specific AnsibleRoleInfo information (usually found in a .yml file by the same name)
                AnsibleRoleNames       = $null
                #AnsibleRoleNames       = @('AuthenticatedPKIHostWindows', 'JavaInterpreterWindows', 'PythonInterpreterWindows', 'RubyInterpreterWindows') #, 'WinRMServerSSH', WinRMServerCertificates', WInRMServerCredSSP; 'HashiVault' )
                PKICertificates        = @('OrganizationalCA', 'ServerCertification(SSL)Certificate ') # DataEncryptionCertificate
                # PKICertificates  = @('OrganizationalCA', 'OrganizationalCAIntermediateAndTrustChain', 'WinRMSSLCertificateForHTTPSAndService', 'ClientAuthforHost', 'UserAuthForLocalUser', 'IISServerAuthForHost') # DataEncryptionCertificate
                Settings               = @(
                    # various temporary directory paths,
                    $global:configRootKeys['SecureTempBasePathConfigRootKey'],
                    # Chocolatey settings on this host# ansibleGroupName=WindowsHosts
                    $global:configRootKeys['ChocolateyCacheLocationConfigRootKey'],
                    # ansible settings on this host# ansibleGroupName=WindowsHosts
                    $global:configRootKeys['ansible_remote_tmpConfigRootKey'],
                    # The location where Chocolatey installs some packages and some programs
                    $global:configRootKeys['ChocolateyLibDirConfigRootKey'],
                    # Internal PackageRepository web-based URI for production packages
                    # ToDo: Do we need to add every one of the 600+ lines of PackageRepository related settings to this list?
                    # ToDo: or should this list be deleted? or is this the correct place to put the values (that correspond to windows hosts in this geolocation)for these settings
                    # web-based URI for NuGet production repositories
                    $global:configRootKeys['PackageRepositoryInternalReleasedNuGetProductionPackagePullUriSchemeConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedNuGetProductionPackagePullUriHostConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedNuGetProductionPackagePullUriPortConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedNuGetProductionPackagePullUriPageConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedNuGetProductionPackagePullUriConfigRootKey'],
                    # web-based URI for ChocolateyGet production repositories
                    $global:configRootKeys['PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriSchemeConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriHostConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriPortConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriPageConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriConfigRootKey'],
                    # web-based URI for PSResourceGet production repositories
                    $global:configRootKeys['PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriHostConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriSchemeConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriPortConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriPageConfigRootKey'],
                    $global:configRootKeys['PackageRepositoryInternalReleasedPSResourceGetProductionPackagePullUriConfigRootKey'],
                    # related to the Get-FileMetadata cmdlet, belongs to ATAP.Utilities.Powershell, present in WindowsHost
                    $global:configRootKeys['FileMetadataBlockSizeConfigRootKey'],
                    $global:configRootKeys['GetFileSignatureAsMetadataConfigRootKey']
                )
            }
            CloudMappedHosts                     = @{}

            MonitoredWindowsHosts                = @{
                ChocolateyPackageNames = @(  'cpu-z', 'gpu-z' )
                # ChocolateyPackageNames = @( 'autoruns', 'cinebench', 'cpu-z', 'gpu-z', 'hwinfo', 'nmap', 'pdq-inventory', 'perfview', 'speedtest', 'sysinternals', 'fiddler', 'wireshark')
                PowershellModuleNames  = $null
                RegistrySettingsNames  = $null
                WindowsFeatureNames    = $null
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['MonitoredWindowsHosts'] $GroupsModifications['MonitoredWindowsHosts']
            }

            HavingSecretsHosts                   = @{
                PowershellModuleNames = @('Microsoft.PowerShell.SecretManagement', 'SecretManagement.BitWarden')
            }

            UIHosts                              = @{
                ChocolateyPackageNames = @('autohotkey', 'brave', 'element-desktop', 'googleChrome', 'grammarly', 'grammarly-chrome', 'grammarly-for-windows', 'notepadplusplus', 'office365proplus', 'powertoys', 'pushbullet', 'putty', 'sharex', 'tineye-chrome')
                PowershellModuleNames  = $null
                WindowsFeatureNames    = $null
                RegistrySettingsNames  = @('EnableAutoTray', 'RemoveShortcutFromNewShortcutFileName', 'ExplorerNavPaneShowAllFolders', 'ExplorerShowFileExt', 'ExplorerShowHiddenFilesAndFolders', 'ExplorerShowHiddenOSFiles', 'DisableCortana', 'HideSyncProviderNotifications')
                AnsibleRoleNames       = @(, 'DittoClipboardManagerWindows') #, 'WinRMServerSSH', WinRMServerCertificates', WInRMServerCredSSP; 'HashiVault' )
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['UIHosts'] $GroupsModifications['UIHosts']
            }
            JenkinsControllerHosts               = @{
                ChocolateyPackageNames = @('gh', 'git', 'invoke-build')
                PowershellModuleNames  = @('xWebAdministration', 'xNetworking' )
                WindowsFeatureNames    = $null # IIS,
                AnsibleRoleNames       = @('WinSWWindows', 'JenkinsControllerWindows')
                # CertificateSettings  = @(, 'IISServerAuthForHost')
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['JenkinsControllerHosts'] $GroupsModifications['JenkinsControllerHosts']
            }
            ProGetPackageRepositoryProviderHosts = @{
                ChocolateyPackageNames = @('proget')
                PowershellModuleNames  = @('Microsoft.PowerShell.PSResourceGet' )
                WindowsFeatureNames    = $null # IIS,
                AnsibleRoleNames       = @('WinSWWindows', 'ProGetPackageRepositoryProviderWindows') # add  SQL Server community
                # CertificateSettings  = @(, 'SQLServerAuthForHost')
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['ProGetPackageRepositoryProviderControllerHosts'] $GroupsModifications['ProGetPackageRepositoryProviderControllerHosts']
            }
            CICDHosts                            = @{
                ChocolateyPackageNames = @('gh', 'git', 'invoke-build')
                # uv is not being kept current on chocolatey, so install it manually if needed
                # https://github.com/astral-sh/uv
                PowershellModuleNames  = $null
                WindowsFeatureNames    = $null
                AnsibleRoleNames       = @('WinSWWindows', 'JenkinsAgentWindows')
                # CertificateSettings  = @(, 'IISServerAuthForHost')
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['CICDHosts'] $GroupsModifications['CICDHosts']
            }
            DeveloperHosts                       = @{
                ChocolateyPackageNames = @('beyondcompare', 'dotUltimate', 'fusionplusplus', 'graphviz', 'ilspy', 'invoke-build', 'jetbrains-rider', 'linqpad', 'msbuild-structured-log-viewer', 'nugetPackageExplorer', 'plaster', 'plantuml', 'postman', 'rufus', 'uv', 'vscode', 'vscode', 'vscode-codespellchecker', 'vscode-csharp', 'vscode-csharpextensions', 'vscode-drawio', 'vscode-editorconfig', 'vscode-gitattributes', 'vscode-gitignore', 'vscode-gitlens', 'vscode-icons', 'vscode-markdownlint', 'vscode-mssql', 'vscode-pull-request-github', 'vscode-powershell', 'vscode-prettier', 'vscode-ruby', 'vscode-test-explorer', 'vscode-test-explorer-liveshare', 'vscode-vsliveshare', 'vscode-yaml') # IIS Manager?
                # uv is not being kept current on chocolatey, so install it manually if needed
                # https://github.com/astral-sh/uv
                PowershellModuleNames  = @('platyPS', 'PSScriptAnalyzer', 'InvokeBuild')
                WindowsFeatureNames    = $null # IIS,
                # Settings              = Get-ClonedAndModifiedHashtable $GroupsDefaults['DeveloperHosts'] $GroupsModifications['DeveloperHosts']
                # NPMPackageNames       =  @('yo', 'generator-code', 'npx' )  # it appears this must be run in the development directory, for VSC code extensions. Or thepath modified, or something
                # VSC Extensions = @('esbenp.prettier-vscode', 'd-koppenhagen.file-tree-to-text-generator', ) ## Need to review, add as needed, and see how many are found on chocolatey
            }
            BuildHosts                           = @{
                ChocolateyPackageNames = @('Invoke-Build', 'docfx', 'graphviz', 'nodejs', 'plantuml')
                # uv is not being kept current on chocolatey, so install it manually if needed
                # https://github.com/astral-sh/uv
                PowershellModuleNames  = @('platyPS', 'PSScriptAnalyzer', 'InvokeBuild')
                WindowsFeatureNames    = $null
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['BuildHosts'] $GroupsModifications['BuildHosts']
            }
            QualityAssuranceHosts                = @{
                ChocolateyPackageNames = @('brave', 'Firefox', 'fusionplusplus', 'GoogleChrome', 'ngrok', 'pester', 'postman', 'xunit') # selenium
                # uv is not being kept current on chocolatey, so install it manually if needed
                # https://github.com/astral-sh/uv
                PowershellModuleNames  = $null
                WindowsFeatureNames    = $null # IIS,
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['QualityAssuranceHosts'] $GroupsModifications['QualityAssuranceHosts']
            }
            # DeploymentHosts                = @{
            #     ChocolateyPackageNames = $null
            #     PowershellModuleNames  = $null
            #     WindowsFeatureNames    = $null # IIS,
            #     # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['DeploymentHosts'] $GroupsModifications['DeploymentHosts']
            # }
            AVEditingHosts                       = @{
                ChocolateyPackageNames = @('audacity', 'audacity-ffmpeg', 'audacity-lame', 'exiftool', 'gimp', 'freevideoeditor', 'gopro-quik', 'imagemagick', 'plexmediaserver', 'spotify', 'vlc', 'xnviewmp')
                PowershellModuleNames  = $null
                WindowsFeatureNames    = $null
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['AVEditingHosts'] $GroupsModifications['AVEditingHosts']
            }
            Printing3DHosts                      = @{
                ChocolateyPackageNames = @('blender', 'cura-new')
                PowershellModuleNames  = $null
                WindowsFeatureNames    = $null
                #AnsibleRoleNames       = @(, 'PythonInterpreter')
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['Printing3DHosts'] $GroupsModifications['Printing3DHosts']
            }
            SocialMediaHosts                     = @{
                ChocolateyPackageNames = @('gitter', 'element-desktop', 'zoom' )
                PowershellModuleNames  = $null
                WindowsFeatureNames    = $null
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['SocialMediaHosts'] $GroupsModifications['SocialMediaHosts']
            }
            PKICertificationAuthorityHosts       = @{
                ChocolateyPackageNames = @('OpenSSL.Light')
                PowershellModuleNames  = @('ATAP.Utilities.Security.Powershell' )
                # WindowsFeatureNames    = $null # certmgr?
                AnsibleRoleNames       = @('PKICertificationAuthority')
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['PKICertificationAuthorityHosts'] $GroupsModifications['PKICertificationAuthorityHosts']
            }
            DatabaseMSSQLHosts                   = @{
                ChocolateyPackageNames = @('mssqlserver2014express', 'dbachecks', 'dbatools', 'sql-server-management-studio')
                # PowershellModuleNames  = @(, 'ATAP.Utilities.Security.Powershell' )
                # WindowsFeatureNames    = $null # certmgr?
                # AnsibleRoleNames       = @(, 'PKICertificationAuthority')
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['PKICertificationAuthorityHosts'] $GroupsModifications['PKICertificationAuthorityHosts']
            }
            GamingHosts                          = @{
                ChocolateyPackageNames = @('steam', 'steam-client')
                #PowershellModuleNames  = @(, 'ATAP.Utilities.Security.Powershell' )
                # WindowsFeatureNames    = $null # certmgr?
                # AnsibleRoleNames       = @(, 'PKICertificationAuthority')
                # Settings               = Get-ClonedAndModifiedHashtable $GroupsDefaults['PKICertificationAuthorityHosts'] $GroupsModifications['PKICertificationAuthorityHosts']
            }
        }
    }


    # ToDo add VSC settings
    # "editor.suggest.snippetsPreventQuickSuggestions": false
    # "editor.quickSuggestions": {
    #     "other": true,
    #     "comments": false,
    #     "strings": false
    # }
    $swCfgGroups = [System.Collections.ArrayList]::new()
    $ansibleInventoryKeys = [System.Collections.ArrayList]($ansibleInventory.Keys)
    for ($ansibleInventoryIndex = 0; $ansibleInventoryIndex -lt $ansibleInventoryKeys.Count; $ansibleInventoryIndex++) {
        $ansibleInventoryKey = $ansibleInventoryKeys[$ansibleInventoryIndex]
        if ($ansibleInventoryKey -eq 'HostNames') {
            $HostNamesKeys = [System.Collections.ArrayList]($ansibleInventory.HostNames.Keys)
            for ($HostNamesIndex = 0; $HostNamesIndex -lt $HostNamesKeys.Count; $HostNamesIndex++) {
                $HostNamesKey = $HostNamesKeys[$HostNamesIndex]
                $ansibleInventoryHostNamesKeys = [System.Collections.ArrayList]($ansibleInventory.HostNames.$HostNamesKey.Keys)
                for ($ansibleInventoryHostNamesIndex = 0; $ansibleInventoryHostNamesIndex -lt $ansibleInventoryHostNamesKeys.Count; $ansibleInventoryHostNamesIndex++) {
                    $Swcf'sKey = $ansibleInventoryHostNamesKeys[$ansibleInventoryHostNamesIndex]
                    switch -regex ($SwCfgsKey) {
                        'Settings | AnsibleGroupNames' {}
                        default {
                            #$ansibleInventoryHostNamesSwCfgNamesKey = $ansibleInventory.HostNames.$HostNamesKey.$SwCfgsKey
                            if ($swCfgGroups -notcontains $SwCfgsKey) { $swCfgGroups += $SwCfgsKey }
                        }

                    }
                }
            }
        }
        if ($ansibleInventoryKey -eq 'AnsibleGroupNames') {
            $AnsibleGroupNamesKeys = [System.Collections.ArrayList]($ansibleInventory.AnsibleGroupNames.Keys)
            for ($AnsibleGroupNamesIndex = 0; $AnsibleGroupNamesIndex -lt $AnsibleGroupNamesKeys.Count; $AnsibleGroupNamesIndex++) {
                $AnsibleGroupNamesKey = $AnsibleGroupNamesKeys[$AnsibleGroupNamesIndex]
                $ansibleInventoryAnsibleGroupNamesKeys = [System.Collections.ArrayList]($ansibleInventory.AnsibleGroupNames.$AnsibleGroupNamesKey.Keys)
                for ($ansibleInventoryAnsibleGroupNamesIndex = 0; $ansibleInventoryAnsibleGroupNamesIndex -lt $ansibleInventoryAnsibleGroupNamesKeys.Count; $ansibleInventoryAnsibleGroupNamesIndex++) {
                    $SwCfgsKey = $ansibleInventoryAnsibleGroupNamesKeys[$ansibleInventoryAnsibleGroupNamesIndex]
                    if ($swCfgGroups -notcontains $SwCfgsKey) { $swCfgGroups += $SwCfgsKey }
                }
            }
        }
    }
    $ansibleGroups = @(, 'WindowsHosts')


    $results = @{
        AnsibleInventory  = $ansibleInventory
        HostNames         = [System.Collections.ArrayList]($ansibleInventory.HostNames.Keys)
        AnsibleGroupNames = [System.Collections.ArrayList]($ansibleInventory.AnsibleGroupNames.Keys)
        SwCfgGroups       = $swCfgGroups
        SwCfgInfos        = $SwCfgInfos
        AnsibleRoleNames  = [System.Collections.ArrayList]($SwCfgInfos.AnsibleRoleInfos.Keys)
    }

    return $results
}
