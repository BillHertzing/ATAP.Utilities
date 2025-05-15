param (
  [string] $ymlGenericTemplate
  , [string] $Path
  # $parsedInventory is a hashtable that specifies all the chocolatey packages, powershell modules, and windows features all the groups
  , [hashtable] $parsedInventory
  , [hashtable] $SwCfgInfos
)

[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

# Gather registry settings
$GatherRegistrySettingsScriptBlock = {
  # Get the registry settings

[void]$sb.Append(@"

# GatherRegistrySettings
- name: GatherRegistrySettings
  hosts: all
  gather_facts: false
  tasks:
"@)
$keys =  @($($($SwCfgInfos.RegistrySettingsInfos).keys))
for ($index = 0; $index -lt $keys.count; $index++) {
  $key = @($($($SwCfgInfos.RegistrySettingsInfos).keys))[$index]
  $registrySetting = $($SwCfgInfos.RegistrySettingsInfos)[$key]
  [void]$sb.Append(@"
      - name: Get the current value of $registrySetting.Name
      ansible.windows.win_reg_stat:
        path: $registrySetting.Name

"@)
}


#     - name: Get the current value of the registry key/property
#     ansible.windows.win_reg_stat:
#     path: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion
#     name: CommonFilesDir
#       register: common_files_dir

#     ansible.windows.win_powershell:
#         executable: pwsh.exe
#         script: |
#           pwsh
#           $Ansible.result = @{

#           }
#           }
#           $Ansible.result =@{
#             PSHome =$PSHome
#             PSVersionTable = $PSVersionTable
#             PSModulePath = $env:PSModulePath
#             ProgramData = $env:ProgramData
#             IsElevated = $(New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
#             UserName = $env:USERNAME
#             NumberOfConfigRootKeys = $global:configRootKeys.count
#             #FastTempBasePathConfigRootKey = $global:configRootKeys['FastTempBasePathConfigRootKey']
#             #FAST_TEMP_BASE_PATH = $global:settings[$global:configRootKeys['FastTempBasePathConfigRootKey']]
#             #'global:settings' = $(Write-hashIndented $global:settings)
#           } | ConvertTo-Json -Depth 99
#       register: fullresults
#       failed_when: fullresults.error | length > 0
#       loop:

#       for ($index = 0; $index -lt @($($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).RegistrySettingsNames).count; $index++) {
#         [void]$sb.Append('          - ' + @($($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).RegistrySettingsNames)[$index])
#         [void]$sb.Append("`n")
#       }
#       [void]$sb.Append(@"
#       when: "'$ansibleGroupName' in group_names"
#   tags: [$ansibleGroupName,RegistrySettings]
# "@)
#     }
}


function Contents {
  $(if ($true) { $(. $GatherRegistrySettingsScriptBlock ) })

  # $(if ($true) { $(. $ChocolateyPackagesForAnsibleGroupNameScriptBlock) })

  # $(if ($true) { $(. $PowershellModulesForAnsibleGroupNameScriptBlock) })

  # $(if ($true) { $(. $RegistrySettingsForAnsibleGroupNameScriptBlock) })

  # $(if ($true) { $(. $RolesForAnsibleGroupNameScriptBlock) })
}


Contents
Set-Content -Path $Path -Value $sb.ToString() # $ymlContents

