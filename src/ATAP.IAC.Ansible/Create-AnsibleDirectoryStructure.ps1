
# Creates a specific directory structure for an ansible IAC
# [Ansible/Directory Layout/Details - charlesreid1](https://charlesreid1.com/wiki/Ansible/Directory_Layout/Details )
param (
  [string] $projectBaseDirectory = '.'
)

# To copy this direcotry structure to your WSL2 home directory, use the following command in a WSL2 terminal
# cd ~; rm -r ~/Ansible; sudo cp -r  '/mnt/c/dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.IAC.Ansible/_generated/ATAP_001/Ansible/' ~; sudo chgrp -R "$(id -gn)" ~/Ansible;sudo chown -R "$(id -un)" ~/Ansible; cd Ansible

# ToDo - Test roles on Windows
# [Use Molecule to test Ansible roles on Windows](https://gregorystorme.medium.com/use-molecule-to-test-ansible-roles-on-windows-5bd40db3e331)

# This function returns the higest version number found in an array of dictionaries having fields both name and version
function Get-HighestVersionNumbers {
  param (
    [Parameter(Mandatory = $true)]
    [array]$Versions
  )

  $packages = @{}
  for ($index = 0; $index -lt $Versions.count; $index++) {
    $version = $Versions[$index]
    if ($packages.ContainsKey($version.name)) {
      # simple string compare won't work for version numbers, convert to a [version] type
      if ([version]$($version.version) -gt [version]$($packages[$version.name])) {
        $packages[$version.name] = $version.version
      }
    }
    else {
      $packages[$version.name] = $version.version
    }
  }

  $result = @{}
  foreach ($name in $packages.Keys) {
    $result[$name] = @{Version = $([version]$packages[$name]).ToString(); AllowPrerelease = $false }
  }

  return $result
}

# region things setup outside of this script
$inventorySourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Wsl2Ubuntu\AnsibleInventory.yml'

# Windows Features Roles are defined a-priori. There (will be) a script to read the existing Windows features of a host, and create the existing installed features and assign them to groups (as roles)
$windowsFeatures = @(@{name = 'RoleFeatureDefender'; version = '20230215.1'; allowprerelease = 'false}' }, @{name = 'RoleFeatureSSH.Server'; version = 'latest'; allowprerelease = 'false}' })
# Need to add the following additional command to Defender feature
# Set-Service -Name WinDefend -StartupType 'Automatic'
$windowsFeaturesInfoSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\WindowsFeaturesInfo.json'
$windowsFeatureInfos = @()
for ($index = 0; $index -lt $windowsFeatures.count; $index++) {
  $windowsFeatureInfos += @{name = $($windowsFeatures[$index]).Name; version = $($windowsFeatures[$index]).Version; PreRelease = $($windowsFeatures[$index]).PreRelease }
}
Set-Content -Path $windowsFeaturesInfoSourcePath -Value $($windowsFeatureInfos | ConvertTo-Json -Depth 99)

# Chocolatey package Roles are defined a-priori. There (will be) a script to read the choco list -lo, and create the existing installed packages and assign them to groups (as roles)
$excludeRegexPattern = '\.install$|^KB\d|^dotnet|^vcredist|^vscode-|^netfx-|^chocolatey-|^version$'
# $chocolateyPackages = $($lines = choco search --lo; $all = @(); for ($index = 0; $index -lt $lines.count; $index++) { $parts = $lines[$index].split(' '); $all += @{name = $($parts[0]); version = $($parts[1]); PreRelease = $false } }; $all | Where-Object { $_.name -notmatch '^$' -and $_.name -notmatch $excludeRegexPattern -and $_.version -match '\d+(\.\d+){0,4}' } | Sort-Object -Property 'name' -uniq  )
# Don't Overwrite - it has added params info for some packages
$chocolateyPackageInfoSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\chocolateyPackageInfo.json'
# $chocolateyPackageInfos = @()
# for ($index = 0; $index -lt $chocolateyPackages.count; $index++) {
#   $chocolateyPackageInfos += @{name = $($chocolateyPackages[$index]).Name; version = $($chocolateyPackages[$index]).Version; PreRelease = $($chocolateyPackages[$index]).PreRelease }
# }
# Set-Content -Path $chocolateyPackageInfoSourcePath -Value $($chocolateyPackageInfos | ConvertTo-Json -Depth 99)

# Powershell module Roles are defined a-priori. There (will be) a script to read the get-module -ListAvailable, and create the existing installed modules  and assign them to groups (as roles)
$excludeRegexPattern = '^\s+$'
# The following line returns a version strucutre for the version, not just a simple string, so it needs to be converted to a [version] type, then to a string
$powershellModules = Get-HighestVersionNumbers $(Get-Module -ListAvailable | Where-Object { $_.name -notmatch '^$' -and $_.name -notmatch $excludeRegexPattern })
$powershellModuleInfoSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\powershellModuleInfo.json'
$powershellModuleInfos = $powershellModules
# $powershellModules.Keys | ForEach-Object{$moduleName = $_

#   $powershellModuleInfos += @{name = $($powershellModules[$index]).Name; version = $($powershellModules[$index]).Version; PreRelease = $($powershellModules[$index]).PreRelease }
# }
# for ($index = 0; $index -lt $powershellModules.count; $index++) {
#   $powershellModuleInfos += @{name = $($powershellModules[$index]).Name; version = $($powershellModules[$index]).Version; PreRelease = $($powershellModules[$index]).PreRelease }
# }
Set-Content -Path $powershellModuleInfoSourcePath -Value $($powershellModules | ConvertTo-Json -Depth 99)

# end region

# region constants defined in this script
# These are names that are common to both the Windows file generation runtime, the Linux Ansible runtime, and the Windows remote host runtimes
$playbookSubdirectory = 'playbooks'
$ansibleSubdirectoryNames = @('group_vars', 'host_vars', $playbookSubdirectory, 'roles', 'scripts')
#$groupNames = $global:settings[$global:configRootKeys['AnsibleGroupNamesConfigRootKey']]
#$roleNames = $global:settings[$global:configRootKeys['AnsibleRoleNamesConfigRootKey']]
$roleSubdirectoryNames = @('tasks', 'handlers', 'templates', 'files', 'vars', 'defaults', 'meta', 'library', 'tests', 'module_utils', 'lookup_plugins', 'scripts')
# the name of the main playbook
$mainPlaybookName = 'main.yml'
# the name of the inventory file
$inventoryFileName = 'inventory.yml'
# The name of the role that installs and configures chocolatey
$installAndConfigureChocolateyRoleName = 'RoleChocolateyInstallAndConfigure'
# ReadMe doccumentation filename
$ReadMeFileName = 'ReadMe.md'
# default name of the main YML file in each subdirectory
$mainYMLFileName = 'main.yml'

# These are the path names for the generated ansible directories and files in the Windows file generation runtime
$generatedDirectoryPath = '_generated'
$generatedProjectDirectoryPath = Join-Path $projectBaseDirectory $generatedDirectoryPath 'ATAP_001'

# define the OS_Names, actionNames
# #  OS_Names are the primary groups in the inventory file $oSNames = @('Windows', 'WSL2Ubuntu')
$lifecycleNames = @('DevelopmentLFC', 'QualityAssuranceLFC', 'StagingLFC', 'ProductionLFC')
$actionNames = @('setup', 'update')

# template for new .yml files
$ymlTemplate = @'
---
# code: language=ansible
# {1} for {2}

'@

# endregion

# generation begins below this line

# generate a play/task/role that sets the MaxMemoryPerShell to 2GB. Clears up problems with Ansible getting the `System.OutOfMemoryException` error
# Attribution: [Error installing Chocolatey via Ansible on Windows](https://stackoverflow.com/questions/30869780/error-installing-chocolatey-via-ansible-on-windows) answer from "Gavin Bunney"

# Get the initial Windows Features
# SSH Stuff - But disable SSH in production machines, use just WinRM (?)
# [Configuring OpenSSH-Server (sshd) on Windows 11](https://erwin.co/configuring-openssh-server-sshd-on-windows-11/)
# State will be present or notpresent for OpenSSH Client and OpenSSH.Server
# Get-WindowsCapability -Online | Where-Object Name -like ‘OpenSSH.Server*’ | Add-WindowsCapability –Online
# Set-Service -Name sshd -StartupType 'Automatic'
# netsh advfirewall firewall add rule name="OpenSSH-Server-In-TCP" dir=in action=allow protocol=TCP localport=22
# Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
# Windows Defender


# Get the windowsFeaturesInformation
$windowsFeaturesInfos = ConvertFrom-Json -Depth 99 -AsHashtable -InputObject $(Get-Content -Path $windowsFeaturesInfoSourcePath -Raw)
# Get the chocolateyPackageInformation
$chocolateyPackageInfos = ConvertFrom-Json -Depth 99 -AsHashtable -InputObject $(Get-Content -Path $chocolateyPackageInfoSourcePath -Raw )
# Get the powershellModuleInformation
$powershellModuleInfos = ConvertFrom-Json -Depth 99 -AsHashtable -InputObject $(Get-Content -Path $powershellModuleInfoSourcePath -Raw)

# ToDo: parse the hostNames, groupNames, and roles out of the inventory file
# $inventorySourcePath
  #   # Need additional arguments to specify that CChoco should be imported into all Powershell scripts that need to control Windows Features `import-module CChoco -scope Global`
  #   # Need additional arguments to specify that DISM should be imported into all Powershell scripts that need to control Windows Features `import-module C:\Windows\System32\WindowsPowerShell\v1.0\Modules\DISM -scope Global`

$parsedInventory = @{
  HostNames              = ('ncat041', 'ncat-ltb1', 'ncat-ltjo', 'ncat044', 'utat01', 'utat022')
  GroupNames             = [ordered]@{ # ('AppDatabaseComputers', 'Database_MSSQL', 'CertificationAuthorityComputers', 'Linux' )
    WindowsHosts           = @{
      ChocolateyPackageNames = @('carbon', '7zip', 'Everything', 'powershell-core', 'vault')
      PowershellModuleNames  = @('Assert', 'PackageManagement', 'NuGet', 'PowerShellGet', 'ChocolateyGet', 'powershell-yaml', 'PSDesiredStateConfiguration', 'PSDscResources', 'PSFramework', 'cChoco') # 'ComputerManagementDsc') # 'DISM',
      RegistrySettingsNames  = $null
      WindowsFeatureNames    = @('RoleFeatureDefender', 'RoleFeatureSSH.Server')
    }
    MonitoredWindowsHosts  = @{
      ChocolateyPackageNames = @('cinebench', 'cpu-z', 'gpu-z', 'hwinfo', 'nmap', 'pdq-inventory', 'perfview', 'speedtest', 'sysinternals', 'fiddler', 'wireshark')
      PowershellModuleNames  = $null
      WindowsFeatureNames    = $null
    }
    UIHosts                = @{
      ChocolateyPackageNames = @('autohotkey', 'brave', 'ditto', 'element-desktop', 'googleChrome', 'notepadplusplus', 'powertoys', 'pushbullet', 'putty')
      PowershellModuleNames  = $null
      WindowsFeatureNames    = $null
    }
    CICDHosts              = @{
      ChocolateyPackageNames = @('gh', 'git')
      PowershellModuleNames  = $null
      CompositeRoleName      = @(, 'JenkinsClient')
      WindowsFeatureNames    = $null
    }
    DeveloperHosts         = @{
      ChocolateyPackageNames = @('beyondcompare', 'graphviz', 'ilspy', 'invoke-build', 'linqpad', 'msbuild-structured-log-viewer', 'nugetPackageExplorer', 'plaster', 'postman', 'vscode')
      PowershellModuleNames  = @('platyPS', 'PSScriptAnalyzer')
      WindowsFeatureNames    = $null
    }
    BuildHosts             = @{
      ChocolateyPackageNames = $null
      PowershellModuleNames  = @(, 'InvokeBuild')
      WindowsFeatureNames    = $null
    }
    QualityAssuranceHosts  = @{
      ChocolateyPackageNames = @('postman', 'xunit', 'pester', 'ngrok')
      PowershellModuleNames  = $null
      WindowsFeatureNames    = $null
    }
    AVEditingHosts         = @{
      ChocolateyPackageNames = @('vlc', 'audacity', 'freevideoeditor')
      PowershellModuleNames  = $null
      WindowsFeatureNames    = $null
    }
    SocialMediaHosts       = @{
      ChocolateyPackageNames = @('gitter', 'element-desktop' )
      PowershellModuleNames  = $null
      WindowsFeatureNames    = $null
    }
    JenkinsControllerHosts = @{
      ChocolateyPackageNames = @(, 'jenkins')
      PowershellModuleNames  = @('xWebAdministration', 'xNetworking' )
      WindowsFeatureNames    = $null
      CompositeRoleNames     = @(, 'JenkinsController')
    }
  }

  # RoleNamesForWindowsFeatures = @{
  #   WindowsHosts = @('RoleFeatureDefender', 'RoleFeatureSSH.Server')
  # }
   # } # ('RootCertificateAuthority', 'choco-package-list-backup', 'chocolatey.server', 'dbachecks', 'dbatools', 'docfx',  'flyway.commandline', 'grammarly-chrome',  'mysql', 'mysql.workbench',  'nuget.commandline', 'OpenSSL.Light', 'plantuml',  'python311', 'ruby', 'sentinel',  'Temurinjre', 'tineye-chrome', )}

}

$hostNames = $parsedInventory.HostNames
$groupNames = $parsedInventory.GroupNames.Keys

# $roleNamesForWindowsFeatures = @(); $parsedInventory.RoleNamesForWindowsFeatures.values | ForEach-Object { $roleNamesForWindowsFeatures += $_ }
# $roleNamesForPackages = @(); $parsedInventory.RoleNamesForPackages.values | ForEach-Object { $roleNamesForPackages += $_ }
# $roleNamesForModules = @(); $parsedInventory.RoleNamesForModules.values | ForEach-Object { $roleNamesForModules += $_ }
# $roleNamesForComposites = @(); $parsedInventory.RoleNamesForComposites.values | ForEach-Object { $roleNamesForComposites += $_ }
$roleNames = $roleNamesForModules + $roleNamesForWindowsFeatures + $roleNamesForPackages # + $roleNamesForComposites

# Create generated directory if it does not exists
New-Item -ItemType Directory -Path $generatedDirectoryPath -ErrorAction SilentlyContinue >$null
# Create generated Project directory
New-Item -ItemType Directory -Path $generatedProjectDirectoryPath -ErrorAction SilentlyContinue >$null
# Create base directory everything else is relative to this location
$baseDirectory = Join-Path $generatedProjectDirectoryPath 'Ansible'
New-Item -ItemType Directory -Path $baseDirectory -ErrorAction SilentlyContinue >$null

# create the direct subdirectories of the $baseDirectory
for ($ansibleSubdirectoryNameIndex = 0; $ansibleSubdirectoryNameIndex -lt $ansibleSubdirectoryNames.count; $ansibleSubdirectoryNameIndex++) {
  New-Item -ItemType Directory -Path $(Join-Path $baseDirectory $ansibleSubdirectoryNames[$ansibleSubdirectoryNameIndex]) -ErrorAction SilentlyContinue >$null
}

# Create inventory file
$inventoryDestinationPath = Join-Path $baseDirectory $inventoryFileName
Set-Content -Path $inventoryDestinationPath -Value $(Get-Content $inventorySourcePath)

# Create group_vars files
& "$projectBaseDirectory\keyed_vars.ps1" $($ymlTemplate -replace '\{1}', 'group_vars') $(Join-Path $baseDirectory 'group_vars') $defaultPerGroupSettings $groupNames

# Create host_vars files
& "$projectBaseDirectory\keyed_vars.ps1" $($ymlTemplate -replace '\{1}', 'host_vars') $(Join-Path $baseDirectory 'host_vars') $defaultPerMachineSettings $hostNames

# Create the main playbook, which goes into the base directory. because the `roles` subdirectory should be relative to the playbook
& "$projectBaseDirectory\main_playbook.ps1" $($ymlTemplate -replace '\{1}', 'main_playbook') $(Join-Path $baseDirectory $mainPlaybookName) $parsedInventory

# All Module installations require the module name, version, and PSEdition (or type)
# Module installations must honor the PSEdition AllUser's path
# Create a role that ensures the PSDesiredStateConfiguration and the PSDscResources modules are installed (for AllUsers)
# Create a role that ensures the cChoco module is installed (for AllUsers)

# Create a role that ensures the PowershellGet module is installed (for AllUsers)

# Create a role that installs chocolatey, and configures chocolatey
# This role will be listed as a dependency in all of the chocolatey package roles
New-Item -ItemType Directory -Path $(Join-Path $baseDirectory 'roles' $installAndConfigureChocolateyRoleName) -ErrorAction SilentlyContinue >$null
$fileToExecutePattern = Join-Path $projectBaseDirectory "$installAndConfigureChocolateyRoleName.ps1"
& "./$fileToExecutePattern" `
  -ymlGenericTemplate $ymlTemplate `
  -roleDirectoryPath $(Join-Path $baseDirectory 'roles' $installAndConfigureChocolateyRoleName) `
  -roleName $installAndConfigureChocolateyRoleName `
  -roleSubdirectoryNames $roleSubdirectoryNames

# Create roles (directories, subdirectories, and files)
$roleNames = @()
for ($groupNameIndex = 0; $groupNameIndex -lt $groupNames.count; $groupNameIndex++) {
  $groupName = $groupNames[$groupNameIndex]
  $roleNames = $($parsedInventory.GroupNames[$GroupName]).CompositeRoleNames #  # $parsedInventory.GroupNames[$GroupName]).CompositeRoleNames.keys
  for ($roleNameIndex = 0; $roleNameIndex -lt $roleNames.count; $roleNameIndex++) {
    $roleName = $roleNames[$roleNameIndex]
    $fileToExecutePattern = "Role$($roleName).ps1" # $parsedInventory.GroupNames[$GroupName]).CompositeRoleNames.keys
    Write-PSFMessage -Level Debug -Message "fileToExecutePattern is $fileToExecutePattern"
    # $matchingFeature = $windowsFeatureInfos | Where-Object { $_.name -eq $roleName }
    # $matchingPackage = $chocolateyPackageInfos | Where-Object { $_.name -eq $roleName }`
    # $matchingModule = $powershellModuleInfos[$roleName] #  | Where-Object { $_.name -eq $roleName }
    # $matchingComposite = $CompositesInfos | Where-Object { $_.name -eq $roleName }
    # if ( $matchingPackage) {
    #   $fileToExecutePattern = 'ChocolateyPackagesAsRoles.ps1'
    # }
    # elseif ($matchingModule) {
    #   $fileToExecutePattern = 'PowershellModulesAsRoles.ps1'
    # }
    # elseif ($matchingFeature) {
    #   $fileToExecutePattern = "$($matchingFeature.Name).ps1"
    # }
    # else {
    #   # default
    #   # ToDO roles that require multiple tasks, or DSCresources
    #   $message = "role $roleName does not have a FileToExecute"
    #   Write-PSFMessage -Level Error -Message $message
    #   throw  $message
    # }
    # If a script exists whose name matches the $fileToExecutePattern, then execute it, which will create the contents of the roleSubdirectory
    if (Test-Path -Path $fileToExecutePattern -PathType Leaf) {
      # create a subdirectory for each role
      New-Item -ItemType Directory -Path $(Join-Path $baseDirectory 'roles' $roleName) -ErrorAction SilentlyContinue >$null
      # create a documentation file for each role
      New-Item -ItemType File -Path $(Join-Path $baseDirectory 'roles' $roleName, $ReadMeFileName) -ErrorAction SilentlyContinue >$null
      switch -regex ($fileToExecutePattern) {
        # 'ChocolateyPackagesAsRoles.ps1' {
        #   & "./$fileToExecutePattern" `
        #     -ymlGenericTemplate $ymlTemplate `
        #     -roleDirectoryPath $(Join-Path $baseDirectory 'roles' $roleName) `
        #     -roleName $roleName `
        #     -roleSubdirectoryNames $roleSubdirectoryNames `
        #     -name $matchingPackage.name `
        #     -version $matchingPackage.version `
        #     -addedParameters $matchingPackage.addedParameters
        #   break
        # }
        # 'PowershellModulesAsRoles.ps1' {
        #   $Parameters = @{
        #     ymlGenericTemplate    = $($ymlTemplate -replace '\{1}', $roleName)
        #     roleDirectoryPath     = $(Join-Path $baseDirectory 'roles' $roleName)
        #     roleName              = $roleName
        #     roleSubdirectoryNames = $roleSubdirectoryNames
        #     name                  = $matchingModule.name
        #     version               = $([version]::new($matchingModule.version.Major, $matchingModule.version.Minor, $matchingModule.version.Build, $(if ($matchingModule.version.Revision -gt 0) { $matchingModule.version.Revision } else { $null })).ToString())
        #   }
        #   & "./$fileToExecutePattern" @Parameters
        #   break
        # }
        default {
          & "./$fileToExecutePattern" `
            -ymlGenericTemplate $($ymlTemplate -replace '\{1}', $roleName) `
            -roleDirectoryPath $(Join-Path $baseDirectory 'roles' $roleName) `
            -roleName $roleName `
            -roleSubdirectoryNames $roleSubdirectoryNames
          break
        }
      }
    }
    else {
      #whoops
      throw
    }
  }

  # create all the role subdirectories
  # for ($roleSubdirectoryIndex = 0; $roleSubdirectoryIndex -lt $roleSubdirectoryNames.count; $roleSubdirectoryIndex++) {
  #   $roleSubdirectoryName = $roleSubdirectoryNames[$roleSubdirectoryIndex]
  #   $roleSubdirectoryPath = $(Join-Path $baseDirectory 'roles' $roleName, $roleSubdirectoryName)
  #   New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  #   # create the contents for each role subdirectory
  #   # contents will vary depending on the role being a chocolatey package, a powershell module, or other

  #   # If a script exists whose name matches the $fileToExecutePattern, then execute it, which will create the contents of the roleSubdirectory
  #   if (Test-Path -Path $fileToExecutePattern -PathType Leaf) {
  #     switch -regex ($roleSubdirectoryName) {
  #       '^handlers|vars|defaults|meta$' {
  #         switch -regex ($fileToExecutePattern) {
  #           default { break }
  #         }
  #         # $contents =  & ./$fileToExecutePattern
  #         # Set-Content -Path $(Join-Path $roleSubdirectoryPath $mainFileName) -Value $contents
  #         break
  #       }
  #       '^files$' {
  #         switch -regex ($fileToExecutePattern) {
  #           default { break }
  #         }
  #         # & "./$fileToExecutePattern" `
  #         #   -ymlGenericTemplate $($($ymlTemplate -replace '\{1}', "Configuration file") -replace '\{2}', "role $roleName") `
  #         #   -directoryPath $roleSubdirectoryPath `
  #         #   -dSCConfigurationName "$($roleName)Configuration" `
  #         #   -dSCConfigurationFilename "$($roleName)Configuration.ps1" `
  #         #   -dSCConfigurationWindowsSourcePath $(Join-Path $baseDirectory 'roles' $roleName, 'files', "$($roleName)Configuration.ps1")
  #         break
  #       }
  #       '^tasks$' {


  #         # $dSCConfigurationTargetDestinationDirectory = "C:\Temp\Ansible\DSCConfigurations\$($roleName)Configuration.ps1"
  #         # & "./$fileToExecutePattern" `
  #         #   -ymlGenericTemplate $($ymlTemplate -replace '\{1}', $roleName) `
  #         #   -directoryPath $roleSubdirectoryPath `
  #         #   -dSCConfigurationName "$($roleName)Configuration" `
  #         #   -dSCConfigurationFilename "$($roleName)Configuration.ps1" `
  #         #   -dSCConfigurationAnsibleSourcePath "roles/$roleName/files/$($roleName)Configuration.ps1" `
  #         #   -dSCConfigurationTargetDestinationDirectory $dSCConfigurationTargetDestinationDirectory # Figure out how to get the real FastTEmp dir from the remote host
  #         break
  #       }
  #       # '^scripts$' {
  #       #   $contents = ./$fileToExecutePattern
  #       #   Set-Content -Path $(Join-Path $roleSubdirectoryPath $scriptsFileName) -Value $contents
  #       #   break
  #       # }
  #       default {
  #         Write-PSFMessage -Level Verbose -Message " role  $roleNames[$roleNameIndex] and subdirectory $roleSubdirectoryNames[$roleSubdirectoryIndex] has no child file"
  #         break
  #       }
  #     }
  #   }
  #   else {
  #     Write-PSFMessage -Level Verbose -Message " role  $roleNames[$roleNameIndex] and subdirectory $roleSubdirectoryNames[$roleSubdirectoryIndex] has no script file with a matching name"
  #   }

  # }
}

# Set the collections used by Create-AnsibleDirectoryStructure.ps1
# $global:settings[$global:configRootKeys['AnsibleHostNamesConfigRootKey']] = ('ncat041', 'ncat-ltb1', 'ncat-ltjo', 'ncat044', 'utat01', 'utat022')
# $global:settings[$global:configRootKeys['AnsibleGroupNamesConfigRootKey']] = ('all', 'Windows', 'WSL2Ubuntu')
# The Windows group is affiliated with many roles. A large set of those roles have a one-to-one relationship with software package/versions installed by chocolatey

# simalrly, the WSL2Ubuntu group is affiliated with a large set of roles that have a one-to-one rleationship with software package/versions installed by apt-get
# The Windows group has roles that are related to Windows Features
# The Windows group has roles that are related to Powershell Package Management
# The instersection of the Windows group and other groups, e.g. webserver or dbserver. invoke roles with

# Define the global:settings for
# create an ansible role for each package installed by chocolatey
# group the chocolatey packages by inventory goup
# create the ansible roles for the Windows group
# $global:settings[$global:configRootKeys['AnsibleRoleNamesConfigRootKey']] = @()
# for ($groupIndex = 0; $groupIndex -lt $global:settings[$global:configRootKeys['AnsibleGroupNamesConfigRootKey']].count; $groupIndex++) {
#   for ($packageIndex = 0; $packageIndex -lt $global:settings[$global:configRootKeys['ChocolateyPackagesConfigRootKey']].count; $packageIndex++) {
#   $packageName = $($global:settings[$global:configRootKeys['ChocolateyPackagesConfigRootKey']])[$packageIndex]
#   if ($($global:settings[$global:configRootKeys['AnsibleGroupNamesConfigRootKey']])[$groupIndex] -eq 'Windows') {
#     $($global:settings[$global:configRootKeys['ChocolateyPackagesConfigRootKey']])[$($global:settings[$global:configRootKeys['AnsibleGroupNamesConfigRootKey']])[$groupIndex]] = @('cpu-z', 'gpu-z')
#   }
#   $global:settings[$global:configRootKeys['AnsibleRoleNamesConfigRootKey']] += "Incorporates$packageName"
# }}
# $global:settings[$global:configRootKeys['AnsibleRoleNamesConfigRootKey']] +=  'IncorporatesNuGetPackageProvider' #,'common', 'AnsibleServers', 'BuildServers', 'JenkinsControllerServers', 'JenkinsClientServers', 'QualityAssuranceServers', 'WebServers', 'DatabaseServers' )


# # define all the possible group_var values
# $groupVarNames = @()
# for ($oSNameIndex = 0; $oSNameIndex -lt $oSNames.count; $oSNameIndex++) {
#   $groupVarNames += '{0}' -f $oSNames[$oSNameIndex]
#   for ($roleNameIndex = 0; $roleNameIndex -lt $roleNames.count; $roleNameIndex++) {
#     $groupVarNames += '{0}-{1}' -f $oSNames[$oSNameIndex], $roleNames[$roleNameIndex]
#     for ($lifecycleNameIndex = 0; $lifecycleNameIndex -lt $lifecycleNames.count; $lifecycleNameIndex++) {
#       $groupVarNames += '{0}-{1}_{2}' -f $oSNames[$oSNameIndex], $roleNames[$roleNameIndex],$lifecycleNames[$lifecycleNameIndex]
#     }
#   }
# }



# 		}
# 	}
# 	default {
# 		New-Item -ItemType File -Path $(join-path $baseDirectory 'roles' $roleNames[$roleNameIndex],$roleSubdirectoryNames[$roleSubdirectoryIndex],'main.yml') -ErrorAction SilentlyContinue >$null
# 		break
# 	}
# }
# if ($roleSubdirectoryNames[$roleSubdirectoryIndex] -match '^tasks|handlers|vars|defaults|meta$') {
#   New-Item -ItemType File -Path $(join-path $baseDirectory 'roles' $roleNames[$roleNameIndex],$roleSubdirectoryNames[$roleSubdirectoryIndex],'main.yml') -ErrorAction SilentlyContinue >$null
# }
# if ($roleSubdirectoryNames[$roleSubdirectoryIndex] -eq 'tests') {
#   New-Item -ItemType File -Path $(join-path $baseDirectory 'roles' $roleNames[$roleNameIndex],$roleSubdirectoryNames[$roleSubdirectoryIndex],'test.yml')  -ErrorAction SilentlyContinue >$null
#   New-Item -ItemType File -Path $(join-path $baseDirectory 'roles' $roleNames[$roleNameIndex],$roleSubdirectoryNames[$roleSubdirectoryIndex],'inventory') -ErrorAction SilentlyContinue >$null
# }

# # Create playbooks
# for ($actionNameIndex = 0; $actionNameIndex -lt $actionNames.count; $actionNameIndex++) {
# 	for ($oSNameIndex = 0; $oSNameIndex -lt $oSNames.count; $oSNameIndex++) {
# 		for ($roleNameIndex = 0; $roleNameIndex -lt $roleNames.count; $roleNameIndex++) {
# 	# certain combinations are not allowed
# 	if (
# 	(($oSNames[$oSNameIndex] -match 'Windows') -and  ($roleNames[$roleNameIndex] -notmatch 'AnsibleServers')) `
# 	-or `
# 	(($oSNames[$oSNameIndex] -match 'OS_WSL2Ubuntu')-and  ($roleNames[$roleNameIndex] -match 'AnsibleServers'))) {
# 	# $path = $(join-path $playbookDirectory $('{0}-{1}{2}.{3}' -f $oSNames[$oSNameIndex], $actionNames[$actionNameIndex], $roleNames[$roleNameIndex],'yml'))
# 	# switch ($roleNames[$roleNameIndex]) {
# 		# 'BuildServer'
# 		# }

# 				New-Item -ItemType File -Path  $(join-path $playbookDirectory $('{0}-{1}{2}.{3}' -f $oSNames[$oSNameIndex], $actionNames[$actionNameIndex], $roleNames[$roleNameIndex],'yml')) -ErrorAction SilentlyContinue >$null
#   		}		}
# 	}
# }
