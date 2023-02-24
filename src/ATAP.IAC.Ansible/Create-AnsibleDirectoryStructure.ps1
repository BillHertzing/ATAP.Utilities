
# Creates a specific directory structure for an ansible IAC
# [Ansible/Directory Layout/Details - charlesreid1](https://charlesreid1.com/wiki/Ansible/Directory_Layout/Details )
param (
  [string] $projectBaseDirectory = '.'
)


# These are names that are common to both the Windows file generation runtime, the Linux Ansible runtime, and the Windows remote host runtimes
$playbookSubdirectory = 'playbooks'
$ansibleSubdirectoryNames = @('group_vars', 'host_vars', $playbookSubdirectory, 'roles', 'scripts')
$groupNames = $global:settings[$global:configRootKeys['AnsibleGroupNamesConfigRootKey']]
$roleNames = $global:settings[$global:configRootKeys['AnsibleRoleNamesConfigRootKey']]
$roleSubdirectoryNames = @('tasks', 'handlers', 'templates', 'files', 'vars', 'defaults', 'meta', 'library', 'tests', 'module_utils', 'lookup_plugins', 'scripts')
# the name of the main playbook
$mainPlaybookName = 'main.yml'
# the name of the inventory file
$inventoryFileName = 'inventory.yml'
# ReadMe doccumentation filename
$ReadMeFileName = 'ReadMe.md'
# default name of the main YML file in each subdirectory
$mainYMLFileName = 'main.yml'

# These are the path names for the generated ansible directories and files in the Windows file generation runtime
$generatedDirectoryPath = '_generated'
$generatedProjectDirectoryPath = Join-Path $projectBaseDirectory $generatedDirectoryPath 'ATAP_001'
$inventorySourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Wsl2Ubuntu\AnsibleInventory.yml'

# define the OS_Names, actionNames
# #  OS_Names are the primary groups in the inventory file $oSNames = @('Windows', 'WSL2Ubuntu')
$lifecycleNames = @('DevelopmentLFC', 'QualityAssuranceLFC', 'StagingLFC', 'ProductionLFC')
$actionNames = @('setup', 'update')

# parse the hostNames, groupNames, and roles out of the inventory file
# $inventorySourcePath

# Chocolatey package Roles are defined a-priori. There (will be) a script to read the choco list -lo, nad create the existinf installed packages
$chocolateyPackages = $($lines = choco search --lo; $all = @(); for ($index = 0; $index -lt $lines.count; $index++) { $parts = $lines[$index].split(' '); $all += @{name=$($parts[0]);version=$($parts[1]);PreRelease=$false}}; $all | ?{$_.name -notmatch '^$' && $_.name -notmatch $excludeRegexPattern && $_.version -match "\d+(\.\d+){0,4}"} | sort -property 'name' -uniq  )
$chocolateyPackageInfo = ({name='7zip';version='1.3';PreRelease=$false},  'audacity ', 'autohotkey', 'autoruns', 'beyondcompare', 'brave', 'choco-package-list-backup', 'chocolatey', 'chocolatey.server', 'cinebench', 'cpu-z', 'dbachecks', 'dbatools', 'ditto', 'docfx', 'Everything', 'fiddler', 'flyway.commandline', 'freevideoeditor', 'gh', 'git', 'gitter', 'GoogleChrome', 'gpu-z', 'grammarly-chrome', 'graphviz', 'hwinfo', 'ilspy', 'invoke-build', 'keepass', 'linqpad', 'msbuild-structured-log-viewer', 'mysql', 'mysql.workbench', 'ngrok', 'nmap', 'notepadplusplus', 'nuget.commandline', 'NugetPackageExplorer', 'OpenSSL.Light', 'pdq-inventory', 'perfview', 'Pester', 'plantuml', 'plaster', 'postman', 'powershell-core', 'powertoys', 'psframework', 'putty', 'python311', 'ruby', 'sentinel', 'speedtest', 'sysinternals', 'Temurinjre', 'tineye-chrome', 'vault', 'visualstudiocode', 'vlc', 'wireshark')
$parsedInventory = @{
  HostNames = ('ncat041', 'ncat-ltb1', 'ncat-ltjo', 'ncat044', 'utat01', 'utat022')
  GroupNames = ('Windows', 'DeveloperComputers', 'TestingComputers', 'AppDatabaseComputers', 'Database_MSSQL', 'CertificationAuthorityComputers', 'Linux' )
  RoleNames = ('7zip', 'cpu-z') # ('RootCertificateAuthority', '7zip',  'audacity ', 'autohotkey', 'autoruns', 'beyondcompare', 'brave', 'choco-package-list-backup', 'chocolatey', 'chocolatey.server', 'cinebench', 'cpu-z', 'dbachecks', 'dbatools', 'ditto', 'docfx', 'Everything', 'fiddler', 'flyway.commandline', 'freevideoeditor', 'gh', 'git', 'gitter', 'GoogleChrome', 'gpu-z', 'grammarly-chrome', 'graphviz', 'hwinfo', 'ilspy', 'invoke-build', 'keepass', 'linqpad', 'msbuild-structured-log-viewer', 'mysql', 'mysql.workbench', 'ngrok', 'nmap', 'notepadplusplus', 'nuget.commandline', 'NugetPackageExplorer', 'OpenSSL.Light', 'pdq-inventory', 'perfview', 'Pester', 'plantuml', 'plaster', 'postman', 'powershell-core', 'powertoys', 'psframework', 'putty', 'python311', 'ruby', 'sentinel', 'speedtest', 'sysinternals', 'Temurinjre', 'tineye-chrome', 'vault', 'visualstudiocode', 'vlc', 'wireshark')
}
$hostNames = $parsedInventory.HostNames
$groupNames = $parsedInventory.GroupNames
$roleNames = $parsedInventory.RoleNames

# template for new .yml files
$ymlTemplate = @'
---
# code: language=ansible
# {1} for {2}

'@


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

# ToDO: pass the inventory source as a parameter
Set-Content -Path $inventoryDestinationPath -Value $(Get-Content $inventorySourcePath)

# Create group_vars files
& "$projectBaseDirectory\keyed_vars.ps1" $($ymlTemplate -replace '\{1}', 'group_vars') $(Join-Path $baseDirectory 'group_vars') $defaultPerGroupSettings $groupNames

# Create host_vars files
& "$projectBaseDirectory\keyed_vars.ps1" $($ymlTemplate -replace '\{1}', 'host_vars') $(Join-Path $baseDirectory 'host_vars') $defaultPerMachineSettings $hostNames

# Create the main playbook, whihc goes into the basedirecotry. because the `roles` subdirectory should be relative to the playbook
& "$projectBaseDirectory\main_playbook.ps1" $($ymlTemplate -replace '\{1}', 'main_playbook') $(Join-Path $baseDirectory $mainPlaybookName) # $(Join-Path $baseDirectory $playbookSubdirectory $mainPlaybookName)


# Create roles directories, subdirectories, and files
for ($roleNameIndex = 0; $roleNameIndex -lt $roleNames.count; $roleNameIndex++) {
  $roleName = ($roleNames)[$roleNameIndex]
  # create a subdirectory for each role
  New-Item -ItemType Directory -Path $(Join-Path $baseDirectory 'roles' $roleName) -ErrorAction SilentlyContinue >$null
  # create a documentation file for each role
  New-Item -ItemType File -Path $(Join-Path $baseDirectory 'roles' $roleName, $ReadMeFileName) -ErrorAction SilentlyContinue >$null
  # create all the role subdirectories
  for ($roleSubdirectoryIndex = 0; $roleSubdirectoryIndex -lt $roleSubdirectoryNames.count; $roleSubdirectoryIndex++) {
    $roleSubdirectoryName = $roleSubdirectoryNames[$roleSubdirectoryIndex]
    $roleSubdirectoryPath = $(Join-Path $baseDirectory 'roles' $roleName, $roleSubdirectoryName)
    New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
    # create the contents for each role subdirectory
    $matchingPackage = $chocolateyPackages | Where-Object { $_.Name -eq $roleName }
    if ( $matchingPackage) {
      $fileToExecutePattern = "ChocolateyPackagesAsRoles.ps1"
    }else{
      $fileToExecutePattern = "PowershellModulesAsRoles.ps1" #ToDO DSC and mnodules
   }
    Write-PSFMessage -Level Debug -Message "fileToExecutePattern is $fileToExecutePattern"
    # If a script exists whose name matches the $fileToExecutePattern, then execute it, which will create the contents of the roleSubdirectory
    if (Test-Path -Path $fileToExecutePattern -PathType Leaf) {
      switch -regex ($roleSubdirectoryName) {
        '^handlers|vars|defaults|meta$' {
          switch -regex ($fileToExecutePattern) {
            default {break}
          }
          # $contents =  & ./$fileToExecutePattern
          # Set-Content -Path $(Join-Path $roleSubdirectoryPath $mainFileName) -Value $contents
          break
        }
        '^files$' {
          switch -regex ($fileToExecutePattern) {
            default {break}
          }
          # & "./$fileToExecutePattern" `
          #   -ymlGenericTemplate $($($ymlTemplate -replace '\{1}', "Configuration file") -replace '\{2}', "role $roleName") `
          #   -directoryPath $roleSubdirectoryPath `
          #   -dSCConfigurationName "$($roleName)Configuration" `
          #   -dSCConfigurationFilename "$($roleName)Configuration.ps1" `
          #   -dSCConfigurationWindowsSourcePath $(Join-Path $baseDirectory 'roles' $roleName, 'files', "$($roleName)Configuration.ps1")
            break
        }
        '^tasks$' {
          switch -regex ($fileToExecutePattern) {
            "ChocolateyPackagesAsRoles.ps1" {
              & "./$fileToExecutePattern" `
            -ymlGenericTemplate $($ymlTemplate -replace '\{1}', $matchingPackage.Name ) `
             -directoryPath $roleSubdirectoryPath `
             -roleName $matchingPackage.Name `
             -packageVersion $matchingPackage.Version
              break
            }
            "PowershellModulesAsRoles.ps1" {
              & "./$fileToExecutePattern" `
            -ymlGenericTemplate $($ymlTemplate -replace '\{1}', $roleName) `
             -directoryPath $roleSubdirectoryPath `
             -roleName $roleName
              break
            }
            default {break}
          }

          # $dSCConfigurationTargetDestinationDirectory = "C:\Temp\Ansible\DSCConfigurations\$($roleName)Configuration.ps1"
          # & "./$fileToExecutePattern" `
          #   -ymlGenericTemplate $($ymlTemplate -replace '\{1}', $roleName) `
          #   -directoryPath $roleSubdirectoryPath `
          #   -dSCConfigurationName "$($roleName)Configuration" `
          #   -dSCConfigurationFilename "$($roleName)Configuration.ps1" `
          #   -dSCConfigurationAnsibleSourcePath "roles/$roleName/files/$($roleName)Configuration.ps1" `
          #   -dSCConfigurationTargetDestinationDirectory $dSCConfigurationTargetDestinationDirectory # Figure out how to get the real FastTEmp dir from the remote host
          break
        }
        # '^scripts$' {
        #   $contents = ./$fileToExecutePattern
        #   Set-Content -Path $(Join-Path $roleSubdirectoryPath $scriptsFileName) -Value $contents
        #   break
        # }
        default {
          Write-PSFMessage -Level Verbose -Message " role  $roleNames[$roleNameIndex] and subdirectory $roleSubdirectoryNames[$roleSubdirectoryIndex] has no child file"
          break
        }
      }
    }
    else {
      Write-PSFMessage -Level Verbose -Message " role  $roleNames[$roleNameIndex] and subdirectory $roleSubdirectoryNames[$roleSubdirectoryIndex] has no script file with a matching name"
    }

  }
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
