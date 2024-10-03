
# Creates a specific directory structure for an ansible IAC
# [Ansible/Directory Layout/Details - charlesreid1](https://charlesreid1.com/wiki/Ansible/Directory_Layout/Details )
# To copy this directory structure to your WSL2 home directory, use the following command in a WSL2 terminal
# cd ~; rm -r ~/Ansible; sudo cp -r  '/mnt/c/dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.IAC.Ansible/_generated/ATAP_001/Ansible/' ~; sudo chgrp -R "$(id -gn)" ~/Ansible;sudo chown -R "$(id -un)" ~/Ansible; cd Ansible

# add the namespace for the custom types defined and used in this module
using namespace ATAP.IAC.Ansible

param (
  [string] $projectBaseDirectory = '.'
)

$assemblyFileName = 'ATAP.IAC.Ansible.dll'
$assemblyFilePath = Join-Path $projectBaseDirectory '..' $assemblyFileName
$assemblyFileInfo = Get-ChildItem $assemblyFilePath
Add-Type -Path $assemblyFileInfo.FullName

# until packaging, dotsource the needed files to import the needed functions
. .\New-PlaybooksTop.ps1
. .\New-PlaybooksNamed.ps1
. .\New-Role.ps1
. .\RoleComponentMeta.ps1
. .\RoleComponentTask.ps1

. .\ScriptblockChocolateyPackages.ps1
. .\ScriptblockCopyFiles.ps1
. .\ScriptblockPinToTaskbar.ps1
. .\ScriptblockRegistrySettings.ps1
. .\ScriptblockShortcut.ps1
. .\ScriptblockSymbolicLinks.ps1
. .\ScriptblockUserWindows.ps1

. .\SubstituteConfigRootKey.ps1

# ToDo: These paths should come from an organization's vault
# ToDo Validate the files exist and can be read

$ansibleInventorySourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Get-AnsibleInventory.ps1'
# $windowsFeaturesInfoSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\WindowsFeaturesInfo.yml'
# $chocolateyPackageInfoSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\ChocolateyPackageInfo.yml'
# $powershellModuleInfoSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\PowershellModuleInfo.yml'
# $registrySettingsInfoSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\RegistrySettingsInfo.yml'
# $nugetPackagesInfoSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\NugetPackagesInfo.yml'
# ToDo: Steps needed to get past filesystem authorizations (credentials and group/role membership)
$ANVaultSecretsSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\security\.ANVaultATAPSecrets.yml'
$ANVaultPasswordFileSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\security\.ANVault_password_file.txt'
$PSVaultSecretsVaultSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\security\.PSVaultATAP_secrets.kdbx'
$PSVaultPasswordFileSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\security\.PSvault_password_file.txt'

# Connect to and register with the  security vaults
$vaultUnLocked = $null # TBD

# Read and parse the files
# ToDo: error handling

# $windowsFeaturesInfos = ConvertFrom-Yaml $(Get-Content -Path $windowsFeaturesInfoSourcePath -Raw  )#  ConvertFrom-Json -Depth 99 -AsHashtable -InputObject $(Get-Content -Path $windowsFeaturesInfoSourcePath -Raw)
# $chocolateyPackageInfos = ConvertFrom-Yaml $(Get-Content -Path $chocolateyPackageInfoSourcePath -Raw )
# $powershellModuleInfos = ConvertFrom-Yaml $(Get-Content -Path $powershellModuleInfoSourcePath -Raw )
# $registrySettingsInfos = ConvertFrom-Yaml $(Get-Content -Path $registrySettingsInfoSourcePath -Raw )
# $nugetPackagesInfos = $null #ConvertFrom-Yaml $(Get-Content -Path $nugetPackagesInfoSourcePath -Raw )


# ToDo - Test roles on Windows
# [Use Molecule to test Ansible roles on Windows](https://gregorystorme.medium.com/use-molecule-to-test-ansible-roles-on-windows-5bd40db3e331)

# ToDo move this to buildtooling package
# This function returns the highest version number found in an array of dictionaries having fields both name and version
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

# ToDo: Packaging, this function will be in ATAP Buildtooling ?
#. "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\Build\ATAP.Utilities.BuildTooling.0.1.0.1\build\Set-LineEndings.ps1"


# ToDo: move the creation of the Info files outside of this script
# # region things setup outside of this script
# # Windows Features Roles are defined a-priori. There (will be) a script to read the existing Windows features of a host, and create the existing installed features and assign them to groups (as roles)
# $windowsFeatures = @(@{name = 'RoleFeatureDefender'; version = '20230215.1'; allowprerelease = 'false}' }, @{name = 'RoleFeatureSSH.Server'; version = 'latest'; allowprerelease = 'false}' })
# # Need to add the following additional command to Defender feature
# # Set-Service -Name WinDefend -StartupType 'Automatic'
# $windowsFeatureInfos = @()
# for ($index = 0; $index -lt $windowsFeatures.count; $index++) {
#   $windowsFeatureInfos += @{name = $($windowsFeatures[$index]).Name; version = $($windowsFeatures[$index]).Version; PreRelease = $($windowsFeatures[$index]).PreRelease }
# }
# Set-Content -Path $windowsFeaturesInfoSourcePath -Value $($windowsFeatureInfos | ConvertTo-Json -Depth 99)


# Chocolatey package Roles are defined a-priori. There (will be) a script to read the choco list -lo, and create the existing installed packages and assign them to groups (as roles)
# ToDo: write a function that will create / update the chocolateyPackageInfo.yml file
# ToDo: see if PreRelease and AddedParamters can be populated from the results of choco search
# $excludeRegexPattern = '\.install$|^KB\d|^dotnet|^vcredist|^vscode-|^netfx-|^chocolatey-|^version$'
# $($lines = choco search --lo;`
#  $all = @{}; `
#  for ($index = 0; $index -lt $lines.count; $index++) {`
#    $parts = $lines[$index].split(' '); `
#    $all[$parts[0]]=@{Version = $parts[1]; PreRelease=$false; AddedParameters = $null}`
#  };`
#  $filteredKeys = $($all.keys) | Where-Object {$key = $_; $key -notmatch $excludeRegexPattern -and $($all[$key]).Version -match '\d+(\.\d+){0,4}' } | Sort-Object -uniq  ); `
#  $filteredChocolateyPackagesInstalled = @{};`
#  $filteredKeys | ForEach-Object{$filteredChocolateyPackagesInstalled[$_] = $all[$_]}

# TBD - Don't Overwrite - it has added params info for some packages
# Set-Content -Path $chocolateyPackageInfoSourcePath -Value $($filteredChocolateyPackagesInstalled | ConvertTo-Yaml)

# # Powershell module Roles are defined a-priori. There (will be) a script to read the get-module -ListAvailable, and create the existing installed modules  and assign them to groups (as roles)
# $excludeRegexPattern = '^\s+$'
# # The following line returns a version structure for the version, not just a simple string, so it needs to be converted to a [version] type, then to a string
# $powershellModules = Get-HighestVersionNumbers $(Get-Module -ListAvailable | Where-Object { $_.name -notmatch '^$' -and $_.name -notmatch $excludeRegexPattern })
# $powershellModuleInfos = $powershellModules
# $powershellModules.Keys | ForEach-Object{$moduleName = $_

#   $powershellModuleInfos += @{name = $($powershellModules[$index]).Name; version = $($powershellModules[$index]).Version; PreRelease = $($powershellModules[$index]).PreRelease }
# }
# for ($index = 0; $index -lt $powershellModules.count; $index++) {
#   $powershellModuleInfos += @{name = $($powershellModules[$index]).Name; version = $($powershellModules[$index]).Version; PreRelease = $($powershellModules[$index]).PreRelease }
# }
# Set-Content -Path $powershellModuleInfoSourcePath -Value $($powershellModules | ConvertTo-Json -Depth 99)
# end region

# Create the ansibleInventory Powershell hashtable from the source file
. $ansibleInventorySourcePath # dot source the ansibleInventory script
$ansibleStructure = Get-AnsibleInventory # found in the ansibleInventorySourcePath script file
$ansibleInventory = $ansibleStructure.AnsibleInventory
# end region

function convertFromYamlWithErrorHandling {
  param (
    # ToDo: error handling
    [string]$path
  )
  # ToDo: error handling
  ConvertFrom-Yaml -Yaml $(Get-Content -Path $path -Raw )
}

function Get-ClonedAndModifiedHashtableFromYamlWithErrorHandling {
  param (
    # ToDo: error handling
    [hashtable] $original
    , [string[]]$paths
  )
  $hashtables = @()
  for ($pathsIndex = 0; $pathsIndex -lt $paths.Count; $pathsIndex++) {
    $path = $paths[$pathsIndex]
    $hashtables += convertFromYamlWithErrorHandling $path
  }
  # ToDo: error handling
  Get-ClonedAndModifiedHashtable $original $hashtables
}


# ToDo - put into global:settings
$ApprovedChocolateyPackageInfoPath = '.\DefaultChocolateyPackageInfo.yml'
$ApprovedPowershellModulesInfoPath = '.\DefaultPowershellModulesInfo.yml'
$ApprovedRegistrySettingsInfoPath = '.\DefaultRegistrySettingsInfo.yml'
$ApprovedWindowsFeaturesInfoPath = '.\DefaultWindowsFeaturesInfo.yml'
$ApprovedAnsibleRolesInfoPath = '.\DefaultAnsibleRolesInfo.yml'

# Create the structure that holds the allowed names and versions of the components
# Combine the default information from this module with the organization's overriding specific non-default information
# ToDo continue to create defaults for each SWConfig type
$SwCfgInfos = @{
  NuGetPackageInfos      = $nugetPackagesInfos
  ChocolateyPackageInfos = Get-ClonedAndModifiedHashtable $(convertFromYamlWithErrorHandling $defaultChocolateyPackageInfoPath) $ansibleStructure.SwCfgInfos.ChocolateyPackageInfos
  PowershellModuleInfos  = Get-ClonedAndModifiedHashtable $(convertFromYamlWithErrorHandling $defaultPowershellModulesInfoPath) $ansibleStructure.SwCfgInfos.PowershellModuleInfos
  RegistrySettingsInfos  = Get-ClonedAndModifiedHashtable $(convertFromYamlWithErrorHandling $defaultRegistrySettingsInfoPath) $ansibleStructure.SwCfgInfos.RegistrySettingsInfos
  WindowsFeatureInfos    = Get-ClonedAndModifiedHashtable $(convertFromYamlWithErrorHandling $defaultWindowsFeaturesInfoPath) $ansibleStructure.SwCfgInfos.WindowsFeatureInfos
  AnsibleRoleInfos       = Get-ClonedAndModifiedHashtable $(convertFromYamlWithErrorHandling $defaultAnsibleRolesInfoPath) $ansibleStructure.SwCfgInfos.AnsibleRoleInfos
}


# region constants defined in this script
# These are names that are common to both the Windows file generation runtime, the Linux Ansible runtime, and the Windows remote host runtimes
$securitySubdirectory = 'security'
$playbooksSubdirectory = 'playbooks'
$ansibleSubdirectoryNames = @($securitySubdirectory, 'group_vars', 'host_vars', $playbooksSubdirectory, 'roles', 'scripts')
$roleSubdirectoryNames = @('tasks', 'handlers', 'templates', 'files', 'vars', 'defaults', 'meta', 'library', 'tests', 'module_utils', 'lookup_plugins', 'scripts')
# the name of the main playbook
$mainPlaybookName = 'main.yml'
# the name of the buildout playbook
$buildoutPlaybookName = 'buildoutPlaybook.yml'

# ReadMe documentation filename
$ReadMeFileName = 'ReadMe.md'
# default name of the main YML file in each subdirectory
$mainYMLFileName = 'main.yml'

# These are the path names for the generated ansible directories and files in the Windows file generation runtime
$generatedDirectoryPath = '../_generated'
$generatedProjectDirectoryPath = Join-Path $projectBaseDirectory $generatedDirectoryPath 'ATAP_001'

# define the OS_Names, actionNames
# #  OS_Names are the primary groups in the inventory file $oSNames = @('Windows', 'WSL2Ubuntu')
$lifecycleNames = @('DevelopmentLFC', 'QualityAssuranceLFC', 'StagingLFC', 'ProductionLFC')
$actionNames = @('setup', 'update')

# template (preamble) for new, empty .yml files
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


# Create generated directory if it does not exists
New-Item -ItemType Directory -Path $generatedDirectoryPath -ErrorAction SilentlyContinue >$null
# Create generated Project directory
New-Item -ItemType Directory -Path $generatedProjectDirectoryPath -ErrorAction SilentlyContinue >$null
# Create base directory everything else is relative to this location
$baseDirectory = Join-Path $generatedProjectDirectoryPath 'Ansible'
New-Item -ItemType Directory -Path $baseDirectory -ErrorAction SilentlyContinue >$null
# Create a generated package ATAP.Utilities.NewComputerSetup with the desired powershell functions


# create the direct subdirectories of the $baseDirectory
for ($ansibleSubdirectoryNameIndex = 0; $ansibleSubdirectoryNameIndex -lt $ansibleSubdirectoryNames.count; $ansibleSubdirectoryNameIndex++) {
  New-Item -ItemType Directory -Path $(Join-Path $baseDirectory $ansibleSubdirectoryNames[$ansibleSubdirectoryNameIndex]) -ErrorAction SilentlyContinue >$null
}

# Get the hostNames and ansibleGroupNames from the $ansibleStructure object
$hostNames = $ansibleStructure.HostNames
$ansibleGroupNames = $ansibleStructure.AnsibleGroupNames

# the names of the inventory files
# ToDo: Create Ansible inventory files from the ansibleInventory object
$inventoryFileNames = [ordered] @{
  NonProductionInventory = @{source = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Wsl2Ubuntu\AnsibleNonProductionInventory.yml'; destination = 'nonproduction_inventory.yml' }
  ProductionInventory    = @{source = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Wsl2Ubuntu\AnsibleProductionInventory.yml'; destination = 'production_inventory.yml' }
}

# Copy the ansible inventory files to their destinations
for ($index = 0; $index -lt $($inventoryFileNames.Keys).count; $index++) {
  $inventoryDestinationPath = Join-Path $baseDirectory $($inventoryFileNames[$index]).destination
  Set-Content -Path $inventoryDestinationPath -Value $(Get-Content $($inventoryFileNames[$index]).source)
}

# [Ansible: Understanding variable precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)
# Combine the source collections, transform them, and create the destination collection
# Dot source the list of configuration keys
. "$PSHOME/global_ConfigRootKeys.ps1"
# Dot source the HostSettings
. "$PSHOME/HostSettings.ps1"

# Copy the Ansible Vault files to their destination
$vaultDestinationDirectory = Join-Path $baseDirectory 'security' # at the root of the baseDirectory
$vaultFileNames = [ordered] @{
  vaultFile         = @{source = $PSVaultSecretsVaultSourcePath; destination = Join-Path $vaultDestinationDirectory $($PSVaultSecretsVaultSourcePath -split '\\')[-1] }
  vaultPasswordFile = @{source = $PSVaultPasswordFileSourcePath; destination = Join-Path $vaultDestinationDirectory $($PSVaultPasswordFileSourcePath -split '\\')[-1] }
}
for ($index = 0; $index -lt $($vaultFileNames.Keys).count; $index++) {
  $destinationPath = $($vaultFileNames[$index]).destination
  Set-Content -Path $destinationPath -Value $(Get-Content $($vaultFileNames[$index]).source)
}

# Create host_vars files
& "$projectBaseDirectory\host_vars.ps1" $($ymlTemplate -replace '\{1}', 'host_vars') $(Join-Path $baseDirectory 'host_vars') $hostNames

# Group_Vars are currently unused, all vars are in host_vars
# Create group_vars files
# & "$projectBaseDirectory\keyed_vars.ps1" $($ymlTemplate -replace '\{1}', 'group_vars') $(Join-Path $baseDirectory 'group_vars') $defaultPerGroupSettings $ansibleGroupNames

# Create the main playbook, which goes into the base directory. because the `roles` subdirectory and playbooks subdirectory should be relative to the main playbook
New-PlaybooksTop -Template $($($ymlTemplate -replace '\{1}', 'main AnsibleGroupNames Playbook') -replace '\{2}', 'all AnsibleGroups') -Path $(Join-Path $baseDirectory $mainPlaybookName) -InventoryStructure $ansibleStructure -ImportDirectory $playbooksSubdirectory -AnsibleGroupName 'yes'

# Create the buildout playbook, which goes into the base directory. because the `roles` subdirectory and playbooks subdirectory should be relative to the main playbook
New-PlaybooksTop -Template $($($ymlTemplate -replace '\{1}', 'HostNames Buildout Playbook') -replace '\{2}', 'all Hosts') -Path $(Join-Path $baseDirectory $buildoutPlaybookName) -InventoryStructure $ansibleStructure -ImportDirectory $playbooksSubdirectory -HostName 'yes'

$playbooksDestinationDirectory = $(Join-Path $baseDirectory $playbooksSubdirectory)

# Create a playbook for each ansibleGroupName, which goes into the playbooks subdirectory
for ($ansibleGroupNameIndex = 0; $ansibleGroupNameIndex -lt $ansibleGroupNames.count; $ansibleGroupNameIndex++) {
  $ansibleGroupName = $ansibleGroupNames[$ansibleGroupNameIndex]
  #if ($ansibleGroupName -ne 'WindowsHosts' ) { continue } # skip things for development
  # The playbook  for each group consists of the common plays, plus importing any roles
  # The playbook may need information about nuget, PowershellGet, chocolatey packages, Windows Features, etc.
  New-PlaybooksNamed -Template $($($ymlTemplate -replace '\{1}', 'playbook') -replace '\{2}', $ansibleGroupName) -Path $(Join-Path $playbooksDestinationDirectory "$($ansibleGroupName)Playbook.yml") -InventoryStructure $ansibleStructure -AnsibleGroupName $ansibleGroupName
}
# Create a buildout playbook for each HostName, which goes into the playbooks subdirectory
for ($hostNameIndex = 0; $hostNameIndex -lt $hostNames.count; $hostNameIndex++) {
  $hostName = $HostNames[$hostNameIndex]
  #if ($HostName -ne 'WindowsHosts' ) { continue } # skip things for development
  # The playbook  for each group consists of the common plays, plus importing any roles
  # The playbook may need information about nuget, PowershellGet, chocolatey packages, Windows Features, etc.
  New-PlaybooksNamed -Template $($($ymlTemplate -replace '\{1}', 'playbook') -replace '\{2}', $hostName) -Path $(Join-Path $playbooksDestinationDirectory "$($hostName)Playbook.yml") -InventoryStructure $ansibleStructure -HostName $hostName
}

# Create the playbook that gathers current infrastructure settings from each host
& "$projectBaseDirectory\New-PlaybookInfrastructureReporting.ps1" $($($ymlTemplate -replace '\{1}', 'reporting playbook') -replace '\{2}', 'all Hosts') $(Join-Path $playbooksDestinationDirectory 'InfrastructureReportingPlaybook.yml') $ansibleStructure $ansibleStructure.SwCfgInfos

# Create roles (directories, subdirectories, and files)
$roleNames = @()
if (-not $(Get-Command 'New-Role')) {
  $message = "the command 'New-Role' does not exist"
  Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
  # toDo catch the errors, add to 'Problems'
  Throw $message
}
# Loop over all the roles defined in the combined structure
# This creates Role Directories, so they can be created in no particular order
$roleNames = [System.Collections.ArrayList]$($SwCfgInfos.AnsibleRoleInfos.Keys)
for ($roleNameIndex = 0; $roleNameIndex -lt $roleNames.count; $roleNameIndex++) {
  $roleName = $roleNames[$roleNameIndex]
  New-Item -ItemType Directory -Path $(Join-Path $baseDirectory 'roles' $roleName) -ErrorAction SilentlyContinue >$null
  # create a documentation file for the role
  New-Item -ItemType File -Path $(Join-Path $baseDirectory 'roles' $roleName, $ReadMeFileName) -ErrorAction SilentlyContinue >$null
  # Execute  the new-Role function to create the tasks, vars, meta, and other RoleComponents
  & New-Role `
    -roleName $roleName `
    -template $ymlTemplate `
    -baseRoleDirectoryPath $(Join-Path $baseDirectory 'roles') `
    -RoleInfo $($SwCfgInfos.AnsibleRoleInfos[$roleName])
}

# create a hostSettings.ps1 file for every host
$hostSettingsFilename = 'hostSettings.ps1'
$hostSettingsFileScriptsSubdirectory = 'utat022'
New-Item -ItemType Directory -Path $(Join-Path $baseDirectory 'scripts' $hostSettingsFileScriptsSubdirectory ) -ErrorAction SilentlyContinue >$null
New-Item -ItemType File -Path $(Join-Path $baseDirectory 'scripts'  $hostSettingsFileScriptsSubdirectory, $hostSettingsFilename) -ErrorAction SilentlyContinue >$null

# settings: Each ansibleGroupName in the ansibleInventory list the name of the settings needed to describe the groupName
# The WindowsHost ansibleGroupName has settings for the Preamble, which is the initializer of a WindowsHost computer
# every level of the Ansible inventory for the organization may contain a settings key
# ToDo:
# Create the settings specific for this host

# parse the inventory for all the host names, parse the groupNames for the settings, loop for each hostname
for ($hostNamesIndex = 0; $hostNamesIndex -lt $hostNames.Count; $hostNamesIndex++) {
  $hostSpecificSettings = @{}
  $hostSpecificDuplicates = @{}
  $ansibleGroupNameAccumulator = @()
  $hostName = $hostNames[$hostNamesIndex]
  for ($ansibleGroupNamesIndex = 0; $ansibleGroupNamesIndex -lt $ansibleGroupNames.Count; $ansibleGroupNamesIndex++) {
    $ansibleGroupName = $ansibleGroupNames[$ansibleGroupNamesIndex]
    if ($($(inventory.hostNames[$hostName]).AnsibleGroupNames -contains $ansibleGroupName)) {
      $ansibleGroupNameAccumulator += $ansibleGroupName
    }
    #  Loop over every groupname the ansibleGroupNameAccumulator contains looking for duplicates
    for ($ansibleGroupNamesIndex = 0; $ansibleGroupNamesIndex -lt $ansibleGroupNameAccumulator.Count; $ansibleGroupNamesIndex++) {
      $ansibleGroupName = $accumulator[$ansibleGroupNamesIndex]
      if ($(inventory.ansiblegroupNames[$ansibleGroupName]).Settings -and $(inventory.ansibleGroupNames[$ansibleGroupName]).Settings.count .ge 0) {
        for ($SettingsIndex = 0; $SettingsIndex -lt $Settings.Count; $SettingsIndex++) {
          $Setting = $Settings[$SettingsIndex]
          if ($SeenKey[$Setting]) {
            # ToDO: parameterSet or argument to control first-or-last priority
            if ($true) {
              # Later settings override earlier ones
              $SeenKey[$Setting] = ${'ansibleGroupName' = $ansibleGroupName;'ansibleGroupNamesIndex' = $ansibleGroupNamesIndex; 'Setting' = $Setting }
            }
            else {
              # First one wins
              $SeenKey[$Setting] = $SeenKey[$Setting]
            }

          }
          else {
            $SeenKey[$Setting] = ${'ansibleGroupName' = $ansibleGroupName;'ansibleGroupNamesIndex' = $ansibleGroupNamesIndex; 'Setting' = $Setting }
          }
        }
      }
    }
    # Loop over every seenKey in groupnameOrder

  }

}
#  make a new hostSettingsFileScriptsSubdirectory for each hostName
#  The following algorithm has not been optimized for either speed or space.
#  Walk every level of the ansible inventory where hostname appears, extract all the settings hashes that exist
#    and order them.
#  pass the ordered array of hashes to Create-AllUsersAllHostsSettings, with the destination being a temporary object
#  write the destination as key value pairs, where key is a configRootKey, and value is a scalar, string, array, or hash
#  write the destination to the file named settings.ps1 and into the hostname vars subdirectory
# ToDo: if needed, write host_vars that are the key/value pair, as well
#  starting with the earliest (lowest priority) setting hash cloneAndModify the current settings with the next settings hashess
# ToDo: modify the CloneAndModify function to accept an -exclude parameter to remove unwanted settings
#  return the new cloned object,
#  store the return value in the accumulator
# after the loop completion of all groupNames the hostName contains, the accumulator has a running copy of the settings hash every step of the loop
# Select the last object in the array
# Walk the hash and emit Names.
#  look for duplicate.
#  For each duplicate, identify the first / lowest place  and the latest / highest place in the hash where the setting exists.
#  Based on a parameterset, select which setting location should be honored. This allows prioritization of the first encounter, or the last encounter, or any other prioritization scheme desired
#  Remove duplicate settings that are not in effect on the named host
#  write the settings to an file having the default encoding and consisting of the .ps1 script file found in the hostName subdirectroy below the scripts subdirectory
cloneAndModify | Set-Content -Path
#  get the union of the settings, ordered
# The Windows group is affiliated with many roles. A large set of those roles have a one-to-one relationship with software package/versions installed by chocolatey

# similarly, the WSL2Ubuntu group is affiliated with a large set of roles that have a one-to-one relationship with software package/versions installed by apt-get
# The Windows group has roles that are related to Windows Features
# The Windows group has roles that are related to Powershell Package Management
# The instersection of the Windows group and other groups, e.g. webserver or dbserver. invoke roles with



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
# 		New-Item -ItemType File -Path $(Join-Path $baseDirectory 'roles' $roleNames[$roleNameIndex],$roleSubdirectoryNames[$roleSubdirectoryIndex],'main.yml') -ErrorAction SilentlyContinue >$null
# 		break
# 	}
# }
# if ($roleSubdirectoryNames[$roleSubdirectoryIndex] -match '^tasks|handlers|vars|defaults|meta$') {
#   New-Item -ItemType File -Path $(Join-Path $baseDirectory 'roles' $roleNames[$roleNameIndex],$roleSubdirectoryNames[$roleSubdirectoryIndex],'main.yml') -ErrorAction SilentlyContinue >$null
# }
# if ($roleSubdirectoryNames[$roleSubdirectoryIndex] -eq 'tests') {
#   New-Item -ItemType File -Path $(Join-Path $baseDirectory 'roles' $roleNames[$roleNameIndex],$roleSubdirectoryNames[$roleSubdirectoryIndex],'test.yml')  -ErrorAction SilentlyContinue >$null
#   New-Item -ItemType File -Path $(Join-Path $baseDirectory 'roles' $roleNames[$roleNameIndex],$roleSubdirectoryNames[$roleSubdirectoryIndex],'inventory') -ErrorAction SilentlyContinue >$null
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
# 	# $path = $(Join-Path $playbookDirectory $('{0}-{1}{2}.{3}' -f $oSNames[$oSNameIndex], $actionNames[$actionNameIndex], $roleNames[$roleNameIndex],'yml'))
# 	# switch ($roleNames[$roleNameIndex]) {
# 		# 'BuildServer'
# 		# }

# 				New-Item -ItemType File -Path  $(Join-Path $playbookDirectory $('{0}-{1}{2}.{3}' -f $oSNames[$oSNameIndex], $actionNames[$actionNameIndex], $roleNames[$roleNameIndex],'yml')) -ErrorAction SilentlyContinue >$null
#   		}		}
# 	}
# }


# # Create a role that installs chocolatey, and configures chocolatey
# # This role will be listed as a dependency in all of the chocolatey package roles
# New-Item -ItemType Directory -Path $(Join-Path $baseDirectory 'roles' $installAndConfigureChocolateyRoleName) -ErrorAction SilentlyContinue >$null
# $fileToExecutePattern = Join-Path $projectBaseDirectory "$installAndConfigureChocolateyRoleName.ps1"
# & "./$fileToExecutePattern" `
#   -ymlGenericTemplate $ymlTemplate `
#   -roleDirectoryPath $(Join-Path $baseDirectory 'roles' $installAndConfigureChocolateyRoleName) `
#   -roleName $installAndConfigureChocolateyRoleName `
#   -roleSubdirectoryNames $roleSubdirectoryNames

