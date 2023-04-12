
# Creates a specific directory structure for an ansible IAC
# [Ansible/Directory Layout/Details - charlesreid1](https://charlesreid1.com/wiki/Ansible/Directory_Layout/Details )
param (
  [string] $projectBaseDirectory = '.'
)
# To copy this directory structure to your WSL2 home directory, use the following command in a WSL2 terminal
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
$chocolateyPackageInfoSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\chocolateyPackageInfo.yml'
# Set-Content -Path $chocolateyPackageInfoSourcePath -Value $($filteredChocolateyPackagesInstalled | ConvertTo-Yaml)

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

# region  ansibleInventory Powershell hashtable
$ansibleInventorySourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Ansible-Inventory.ps1'
$ansibleInventory = . $ansibleInventorySourcePath
# end region

# region constants defined in this script
# These are names that are common to both the Windows file generation runtime, the Linux Ansible runtime, and the Windows remote host runtimes
$playbooksSubdirectory = 'playbooks'
$ansibleSubdirectoryNames = @('group_vars', 'host_vars', $playbooksSubdirectory, 'roles', 'scripts')
$roleSubdirectoryNames = @('tasks', 'handlers', 'templates', 'files', 'vars', 'defaults', 'meta', 'library', 'tests', 'module_utils', 'lookup_plugins', 'scripts')
# the name of the main playbook
$mainPlaybookName = 'main.yml'

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
$chocolateyPackageInfos = ConvertFrom-Yaml $(Get-Content -Path $chocolateyPackageInfoSourcePath -Raw )
# Get the powershellModuleInformation
$powershellModuleInfos = ConvertFrom-Json -Depth 99 -AsHashtable -InputObject $(Get-Content -Path $powershellModuleInfoSourcePath -Raw)

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

# Get the hostNames and groupNames from the $ansibleInventory object
$hostNames = $ansibleInventory.HostNames.Keys
$groupNames = $ansibleInventory.GroupNames.Keys

# the names of the inventory files
# ToDo: Create from ansibleInventory object
$inventoryFileNames = [ordered] @{
  NonProductionInventory = @{source = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Wsl2Ubuntu\AnsibleNonProductionInventory.yml'; destination = 'nonproduction_inventory.yml' }
  ProductionInventory    = @{source = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Wsl2Ubuntu\AnsibleProductionInventory.yml'; destination = 'production_inventory.yml' }
}

# ToDo: Create Ansible inventory files from the ansibleInventory object
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

# Create host_vars files
& "$projectBaseDirectory\host_vars.ps1" $($ymlTemplate -replace '\{1}', 'host_vars') $(Join-Path $baseDirectory 'host_vars') $defaultPerMachineSettings $hostNames

# Group_Vars are currently unused, all vars are in host_vars
# Create group_vars files
# & "$projectBaseDirectory\keyed_vars.ps1" $($ymlTemplate -replace '\{1}', 'group_vars') $(Join-Path $baseDirectory 'group_vars') $defaultPerGroupSettings $groupNames

# Create the main playbook, which goes into the base directory. because the `roles` subdirectory and playbooks subdirectory should be relative to the main playbook
& "$projectBaseDirectory\main_playbook.ps1" $($ymlTemplate -replace '\{1}', 'plays') $(Join-Path $baseDirectory $mainPlaybookName) $ansibleInventory $playbooksSubdirectory

$playbooksDestinationDirectory = $(Join-Path $baseDirectory $playbooksSubdirectory)

# Create a playbook for each groupname, which goes into the playbooks subdirectory
for ($groupNameIndex = 0; $groupNameIndex -lt $groupNames.count; $groupNameIndex++) {
  $groupName = $groupNames[$groupNameIndex]
  #if ($groupName -ne 'WindowsHosts' ) { continue } # skip things for development
  # The playbook  for each group consists of the common plays, plus importing any roles
  & "$projectBaseDirectory\groupname_playbooks.ps1" $($ymlTemplate -replace '\{1}', 'plays') $(Join-Path $playbooksDestinationDirectory "$($groupName)Playbook.yml") $ansibleInventory $groupName
}

# All Module installations require the module name, version, and PSEdition (or type)
# Module installations must honor the PSEdition AllUser's path
# Create a role that ensures the PSDesiredStateConfiguration and the PSDscResources modules are installed (for AllUsers)

# Create a role that ensures the PowershellGet module is installed (for AllUsers)

# The chocolatey Ansible module will ensure that chocolatey is loaded on a remote host
# Create roles (directories, subdirectories, and files)
$roleNames = @()
for ($groupNameIndex = 0; $groupNameIndex -lt $groupNames.count; $groupNameIndex++) {
  $groupName = $groupNames[$groupNameIndex]
  $roleNames = $($ansibleInventory.GroupNames[$GroupName]).AnsibleRoleNames
  for ($roleNameIndex = 0; $roleNameIndex -lt $roleNames.count; $roleNameIndex++) {
    $roleName = $roleNames[$roleNameIndex]
    $fileToExecutePattern = "Role$($roleName).ps1"
    Write-PSFMessage -Level Debug -Message "fileToExecutePattern is $fileToExecutePattern"
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
      throw "$fileToExecutePattern not found"
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

# The Windows group is affiliated with many roles. A large set of those roles have a one-to-one relationship with software package/versions installed by chocolatey

# simalrly, the WSL2Ubuntu group is affiliated with a large set of roles that have a one-to-one rleationship with software package/versions installed by apt-get
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


# # Create a role that installs chocolatey, and configures chocolatey
# # This role will be listed as a dependency in all of the chocolatey package roles
# New-Item -ItemType Directory -Path $(Join-Path $baseDirectory 'roles' $installAndConfigureChocolateyRoleName) -ErrorAction SilentlyContinue >$null
# $fileToExecutePattern = Join-Path $projectBaseDirectory "$installAndConfigureChocolateyRoleName.ps1"
# & "./$fileToExecutePattern" `
#   -ymlGenericTemplate $ymlTemplate `
#   -roleDirectoryPath $(Join-Path $baseDirectory 'roles' $installAndConfigureChocolateyRoleName) `
#   -roleName $installAndConfigureChocolateyRoleName `
#   -roleSubdirectoryNames $roleSubdirectoryNames

