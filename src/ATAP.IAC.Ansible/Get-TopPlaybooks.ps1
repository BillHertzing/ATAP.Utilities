# Define the main playbook
param (
  [string] $ymlGenericTemplate
  , [string] $Path
  # $parsedInventory is a hashtable that specifies all the chocolatey packages, powershell modules, and windows features all the groups
  , [hashtable] $parsedInventory
  ,[string] $playbooksSubdirectory
)

# script variables used in all scriptblocks
$hostNames = $($parsedInventory.HostNames.Keys)
$groupNames = $($parsedInventory.GroupNames.Keys) # enclosing the keycollection returned by .Keys inside a subexpressions converts it to an array of strings


#state: "{{ registry_properties[item]['state']|default( {{ 'Absent' if (action_type == 'Uninstall') else 'Present'}} ) }}"


function Contents {
  param(
    [string] $name
  )
  [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
  [void]$sb.Append(@"
- name: Top Play
  hosts: all
  gather_facts: false
  tasks:
    - name: Print action_type variable
      debug:
        var: action_type

# Include the playbook for every group

"@)

for ($groupNameIndex = 0; $groupNameIndex -lt $groupNames.count; $groupNameIndex++) {
  $groupName = $groupNames[$groupNameIndex]
  # if ($groupName -ne 'WindowsHosts' ) { continue } # skip things for development

  [void]$sb.Append(@"
- import_playbook: "$playbooksSubdirectory/$($groupName)Playbook.yml"

"@)
}

$sb.ToString()

# $(. $ChocolateyPackagesForGroupNameScriptBlock)

# # ChocolateyPackages Per Group
# $(if ($false) {$(. $ChocolateyPackagesForGroupNameScriptBlock)})

# # PowershellModules Per Group
# $(if ($false) {$(. $PowershellModulesForGroupNameScriptBlock)})

# # Registry Settings per Group
# $(if($true) {$(. $RegistrySettingsForGroupNameScriptBlock)})

# # Roles per Group
# $(if($true) {$(. $RolesForGroupNameScriptBlock)})

# "@
}


$ymlContents = $ymlGenericTemplate -replace '\{2}', 'Main Playbook'

# ToDo: get the formatting correct, so that we don't have to run this global search and replace
$ymlContents += $($($(Contents) -split "`n") | ForEach-Object { $_ -replace '^\s{0,1}-', '-' }) -join "`n"
Set-Content -Path $Path -Value $ymlContents


# - name: Print group_names
#   debug:
#     var: group_names

# - name: Print group names
#   debug:
#     var: item
#   loop: "{{ group_names }}"

# - name: Print information about the group for each group (produces the hostnames that belong to the group)
#   debug:
#     var: groups[item]
#   loop: "{{ group_names }}"

# - name: Print vars dictionary for each group
#   debug:
#     var: groups[item].vars
#   loop: "{{ group_names }}"
#   when: "'vars' in group[item] | default({}) "

# - name: Print roles dictionary for each group
#   debug:
#     var: groups[item].vars.roles
#   loop: "{{ group_names }}"

# - name: Execute roles for each group
#   include_role:
#     name: "{{ item }}"
#   loop: "{{ group_names }}"
#   when: "'vars' in groups[item] | default({}) and 'roles' in groups[item].vars | default({})"
# - name: Print role names
#   debug:
#     var: item
#   loop: "{{ role_names }}"

# - name: Print information about the role for each role
#   debug:
#     var: groups[item]
#   loop: "{{ group_names }}"

# - name: Print role_names
#   debug:
#     var: role_names

# - name: debug variables
#   debug:
#     msg: "ars are {{ hostvars[inventory_hostname] }} groupNameis {{ item }}  }} "
#   loop: "{{ hostvars[inventory_hostname].group_names }}"

# - name remove all from groups
#   set_fact:
#     dict2: "{{dict2 |combine({item.key: item.value})}}"
#   when: "{{item.key not in ['all']}}"
#   with_dict: "{{groups[group_name]}}"

# - name: debug variables
#   debug:
#     var:  groups[group_name]
#   loop: "{{ groups | dict(exclude=['all']) }}" # "{{ hostvars[inventory_hostname].group_names | dict(exclude=['all']) }}"
#   loop_control:
#     loop_var: group_name
# vars:
#   item_roles: "{{ groupvars[item]['roles']|default([]) }}"
# when: item_roles|length > 0

# - name: Get all roles assigned to host's groups
#   set_fact:
#     all_roles: "{{ all_roles|default([]) + hostvars[item]['vars']['roles']|default([]) }}"
#   loop: "{{ hostvars[inventory_hostname].group_names }}"
#   when: hostvars[item]['vars']['roles']|default([])|length > 0

# - name: debug variables
#   debug:
#     msg: "{{ all_roles|default([]) }}"

# - name: Include roles from host's groups
#   include_role:
#     name: "{{ item }}"
#   loop:  "{{ all_roles|default([]) }}"

# - name: Load all vars for host's groups, works for vars defined in files
# vars:
#   group_vars: "{{ hostvars[inventory_hostname].group_names | map('regex_replace', '^(.*)$', '\\1.vars') | list }}"
# include_vars:
#   file: "{{ item }}"
#   name: "{{ item | regex_replace('(.*).vars', '\\1') }}"
# loop: "{{ group_vars }}"
# when: item is match('.*.vars')

# - name: debug variables
#   debug:
#     msg: "{{ item }} and {{ item.roles|default([]) }} "
#   loop: "{{ hostvars[inventory_hostname].group_names }}"
#   vars:
#     item_roles: "{{ hostvars[item]['vars']['roles']|default([]) }}"
#   when: item_roles|length > 0

#  $EProperty = @{ Name = 'TestEnvironmentVariable'; Value = 'TestValue'; Ensure = 'Present'; Path = $false; Target = @('Process', 'Machine')}
#  $fProperty = @{ Name = 'Environment'; ModuleName = 'PSDscResources'; Property = $EProperty; Method = 'Test'}

### THis works
# - name: install package
#   win_chocolatey:
#     name: '$name'
#     version: '{{ version }}'
#     allow_prerelease: '{{ allow_prerelease }}'
#     state: present
#   register: install
#   when:  "action_type == 'Install'"

# - name: remove package
#   win_chocolatey:
#     name: '$name'
#     version: '{{ version }}'
#     allow_prerelease: '{{ allow_prerelease }}'
#     state: absent
#   register: install
#   when:  "action_type == 'Uninstall'"


### End THis Works

# - name: Gather Chocolatey facts
#   win_chocolatey_facts:
#   when:  "action_type == 'Check'"

# - name: Select dictionary with name = '$name'
#   set_fact:
#     selected_dict: "{{ ansible_chocolatey.packages | selectattr('package', 'equalto', '$name') | first }}"

# - name: validate actual version returned for $name is the expected value
#   assert:
#     that:
#       - "'{{ selected_dict.version }}' == '{{ version }}'"
#     fail_msg: "installed version is incorrect. expecting '{{ version }}' got '{{selected_dict.version}}' "
#     success_msg: "Correct"
#   when:  "action_type == 'Check'"


# loop: "{{ ansible_chocolatey.packages | selectattr('name', 'match', '^$roleName$') | list }}" # pick an item from a list of dictionaries based on the value of a field of the dictionary

#   - name: show the ansible_user
#   debug:
#     var: ansible_user

# - name: Ensure module is present on target
#   win_psmodule:
#     name: cChoco
#     repository: PSGallery

# - name: Apply DSC configuration to install chocolatey
#   win_dsc:
#     resource_name: cChocoInstaller
#       InstallDir = C:\Temp\chocotesting

# InstallDir = 'C:\temp\chocotesting'
#InstallDir = 'C:/temp/chocotesting'
# Value  = 'Desired State Configuration'`
# Target = 'Process'`
#        Ensure = 'Present'`

# - name: Copy DSC configuration script to target system
#   win_copy:
#     src: $dSCConfigurationAnsibleSourcePath
#     dest:  $dSCConfigurationTargetDestinationDirectory

#     # - name: Apply DSC configuration
#     #   ansible.windows.win_powershell:
#     #     executable: pwsh.exe
#     #     script:
#     #       Invoke-DscResource -Path $dSCConfigurationTargetDestinationDirectory -Name $dSCConfigurationName -Method Set -Verbose

#     #   $commonParams = @{
#     #     Name = 'WindowsFeature'
#     #     Property = @{ Name = 'cChocoInstaller'; InstallDir = 'C:/temp/chocotesting'}
#     #     ModuleName = 'cChoco'
#     #     Verbose = $true
#     # }

# - name: Apply DSC configuration
#   ansible.windows.win_powershell:
#     executable: pwsh.exe
#     script:
#       Invoke-DscResource -Name 'cChoco' -Method Test -Property @{`
#         Name   = 'cChocoInstaller'`
#       }
#     # args:
#     #   chdir: .


# - name: Set the cache location
# win_chocolatey_config:
#   name: cacheLocation
#   state: present
#   value: C:\Temp\chocotesting

# - name: Select dictionary with name = '$name'
#   set_fact:
#     selected_dict: "{{ ansible_chocolatey.packages | selectattr('package', 'equalto', '$name') | first }}"

# - name: validate actual version returned for $name is the expected value
#   assert:
#     that:
#       - selected_dict.version == {{ version }}
#     fail_msg: "installed version is incorrect"
#     success_msg: "Correct"
#   when:  "action_type == 'Check'"

# loop: "{{ ansible_chocolatey.packages | selectattr('name', 'match', '^$roleName$') | list }}" # pick an item from a list of dictionaries based on the value of a field of the dictionary

