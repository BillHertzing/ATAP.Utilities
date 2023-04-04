# Define the playbooks for each groupname
param (
  [string] $ymlGenericTemplate
  , [string] $Path
  # $parsedInventory is a hashtable that specifies all the chocolatey packages, powershell modules, and windows features all the groups
  , [hashtable] $parsedInventory
  , [string] $groupName
)

# use a local $sb for all operations
[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

$addedParametersScriptblock = { if ($addedParameters) {
    [void]$sb.Append('Params: "')
    foreach ($ap in $addedParameters) { [void]$sb.Append("/$ap ") }
    [void]$sb.Append('"')
  }
}

$ChocolateyPackagesForGroupNameScriptBlock = {
  # if($groupName -ne 'WindowsHosts' ) {continue} # skip things for development
  if ($($parsedInventory.GroupNames[$groupName]).ContainsKey('ChocolateyPackageNames')) { # process for $groupName only if the ChocolateyPackageNames key exists
    if ($null -ne $($parsedInventory.GroupNames[$groupName]).ChocolateyPackageNames) {
      [void]$sb.Append(@"

# ChocolateyPackages Per Group
- name: Install the Chocolatey Packages defined for the group '$groupName'
  hosts: all
  gather_facts: false
  tasks:
    - name: Load Chocolatey Package information JSON file
      set_fact:
        chocolateypackages_properties: "{{ lookup('file', '/mnt/c/Dropbox/whertzing/GitHub/ATAP.IAC/chocolateyPackageInfo.yml') | from_yaml }}"

    - name: Install the Chocolatey Packages
      win_dsc:
        resource_name: cChocoPackageInstaller
        Name: "{{ item }}"
        Version: "{{ chocolateypackages_properties[item]['Version'] }}"
        Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
        $(. $addedParametersScriptblock) # ToDo Fix AddedParameters for chocolatey installation
      loop:

"@
      )
      for ($index = 0; $index -lt @($($($parsedInventory.GroupNames)[$groupName]).ChocolateyPackageNames).count; $index++) {
        [void]$sb.Append('        - ' + @($($($parsedInventory.GroupNames)[$groupName]).ChocolateyPackageNames)[$index])
        [void]$sb.Append("`n")
      }
      [void]$sb.Append(@"
      when: "'$groupName' in group_names "
  tags: [$groupname, ChocolateyPackages]
"@)
    }
  }
}

$PowershellModulesForGroupNameScriptBlock = {
  # if ($groupName -ne 'WindowsHosts' ) { continue } # skip things for development
  if ($($parsedInventory.GroupNames[$groupName]).ContainsKey('PowershellModuleNames')) { # process for $groupName only if the PowershellModuleNames key exists
    if ($null -ne $($parsedInventory.GroupNames[$groupName]).PowershellModuleNames) {
      [void]$sb.Append(@"

# Powershell Modules per Group
- name: Install Powershell modules For $groupName
  hosts: all
  gather_facts: false
  tasks:
    - name: Load Powershell Module information JSON file
      set_fact:
        module_properties: "{{ lookup('file', '/mnt/c/Dropbox/whertzing/GitHub/ATAP.IAC/powershellModuleInfo.json') | from_json }}"

    - name: Install the modules defined for each group
      community.windows.win_psmodule:
        name: "{{ item }}"
        state: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
        version: "{{ module_properties[item]['Version'] }}"
        allow_prerelease: "{{ module_properties[item]['AllowPrerelease'] }}"
      loop:

"@)
      for ($index = 0; $index -lt @($($($parsedInventory.GroupNames)[$groupName]).PowershellModuleNames).count; $index++) {
        [void]$sb.Append('        - ' + @($($($parsedInventory.GroupNames)[$groupName]).PowershellModuleNames)[$index])
        [void]$sb.Append("`n")
      }
      [void]$sb.Append(@"
      when: "'$groupName' in group_names "
  tags: [$groupname, PowershellModules]
"@)
    }
  }
}

$RegistrySettingsForGroupNameScriptBlock = {
  # if($groupName -ne 'WindowsHosts' ) {continue} # skip things for development
  if ($($parsedInventory.GroupNames[$groupName]).ContainsKey('RegistrySettingsNames')) { # process for $groupName only if the RegistrySettingsNames key exists
    if ($null -ne $($parsedInventory.GroupNames[$groupName]).RegistrySettingsNames) {
      [void]$sb.Append(@"

# Registry Settings per Group
- name: Install Registry Settings For $groupName
  hosts: all
  gather_facts: false
  tasks:
    - name: Load Registry Settings information JSON file
      set_fact:
        registry_properties: "{{ lookup('file', '/mnt/c/Dropbox/whertzing/GitHub/ATAP.IAC/RegistrySettingsInfo.yml') | from_yaml }}"

    - name: Set Registry values for each group
      win_regedit:
        path: "{{ registry_properties[item]['path'] }}"
        name: "{{ registry_properties[item]['name'] }}"
        data: "{{ registry_properties[item]['data']|default(None) }}"
        type: "{{ registry_properties[item]['type']|default('dword') }}"
      loop:

"@)
      for ($index = 0; $index -lt @($($($parsedInventory.GroupNames)[$groupName]).RegistrySettingsNames).count; $index++) {
        [void]$sb.Append('          - ' + @($($($parsedInventory.GroupNames)[$groupName]).RegistrySettingsNames)[$index])
        [void]$sb.Append("`n")
      }
      [void]$sb.Append(@"
      when: "'$groupName' in group_names"
  tags: [$groupname,RegistrySettings]
"@)
    }
  }
}
#state: "{{ registry_properties[item]['state']|default( {{ 'Absent' if (action_type == 'Uninstall') else 'Present'}} ) }}"

$RolesForGroupNameScriptBlock = {
  # if($groupName -ne 'WindowsHosts' ) {continue} # skip things for development
  if ($($parsedInventory.GroupNames[$groupName]).ContainsKey('AnsibleRoleNames')) { # process for $groupName only if the AnsibleRoleNames key exists
    if ($null -ne $($parsedInventory.GroupNames[$groupName]).AnsibleRoleNames) {
      # playbooks are in the $basedirectory/playbooks, while roles are in basedirectory/roles. But roles are searched below the playbooks dir. So to find a role, requires a custom role path, ""../roles/""
      [void]$sb.Append(@"

# Roles per Group
- name: Install roles For $groupName
  hosts: all
  gather_facts: false
  tasks:
    - name: Include the following role on all the hosts in $groupName
      include_role:
        name: "{{ roleItem }}"
      loop:

"@)
      $roleNames = @($($parsedInventory.GroupNames[$groupName]).AnsibleRoleNames)
      for ($roleNameIndex = 0; $roleNameIndex -lt $roleNames.count; $roleNameIndex++) {
        $roleName = $roleNames[$roleNameIndex]
        # Ansible expects the roles subdirectory is relative to the playbook. If a child playbook is "included" in a parent playbook, and the child playbook includes a role, bu default it expects the roles subdirectory to be a child of the child playbook's subdirectory.
        #  Our Ansible directory layout places the roles subdirectory as a peer of the playbooks subdirectory, hence, when including a role, the path must go up to the parent, then down to roles subdirectory, i.e., ""../roles/""
        [void]$sb.Append('        - ../roles/' + $roleName)
        [void]$sb.Append("`n")
      }
      [void]$sb.Append(@"
      loop_control:
        loop_var: roleItem
      when: "'$groupName' in group_names "

"@)
     # $roleNamesStr = $roleNames -join ',' # $roleNamesStr,
      [void]$sb.Append(@"
  tags: [$groupname,Roles]
"@)
    }
  }
}

function Contents {
  $(if ($true) { $(. $ChocolateyPackagesForGroupNameScriptBlock) })

  $(if ($true) { $(. $PowershellModulesForGroupNameScriptBlock) })

  $(if ($true) { $(. $RegistrySettingsForGroupNameScriptBlock) })

  $(if ($true) { $(. $RolesForGroupNameScriptBlock) })
}

[void]$sb.AppendLine($($ymlGenericTemplate -replace '\{2}', "groupname $groupName"))
#$ymlContents = $ymlGenericTemplate -replace '\{2}', "groupname $groupName"
# ToDo: get the formatting correct, so that we don't have to run this global search and replace
Contents
#$ymlContents += $($($(Contents -sb $sb) -split "`n") | ForEach-Object { $_ -replace '^\s{0,1}-', '-' }) -join "`n"
Set-Content -Path $Path -Value $sb.ToString() # $ymlContents


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
#     msg: "hostvars are {{ hostvars[inventory_hostname] }} groupNameis {{ item }}  }} "
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

