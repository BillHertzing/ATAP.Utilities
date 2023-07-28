
<#
.SYNOPSIS
Short description
.DESCRIPTION
Long description
.EXAMPLE
Example of how to use this cmdlet
.EXAMPLE
Another example of how to use this cmdlet
.INPUTS
Inputs to this cmdlet (if any)
.OUTPUTS
Output from this cmdlet (if any)
.NOTES
General notes
.COMPONENT
The component this cmdlet belongs to
.ROLE
The role this cmdlet belongs to
.FUNCTIONALITY
The functionality that best describes this cmdlet
#>
function Get-PlaybooksNamed {
[CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
SupportsShouldProcess = $true,
PositionalBinding = $false,
ConfirmImpact = 'Medium')]
# [Alias()]
# [OutputType([Object])]
Param (
# Template help description
[Parameter(Mandatory = $true,
  Position = 0,
  ValueFromPipeline = $false,
  ValueFromPipelineByPropertyName = $false,
  ValueFromRemainingArguments = $false)
]
[ValidateNotNull()]
[ValidateNotNullOrEmpty()]
$Template
, # Name help description
[Parameter(Mandatory = $true,
  Position = 1,
  ValueFromPipeline = $false,
  ValueFromPipelineByPropertyName = $false,
  ValueFromRemainingArguments = $false)
]
[ValidateNotNull()]
[ValidateNotNullOrEmpty()]
$Path
, # InventoryStructure help description
[Parameter(Mandatory = $true,
  Position = 2,
  ValueFromPipeline = $false,
  ValueFromPipelineByPropertyName = $false,
  ValueFromRemainingArguments = $false)
]
[ValidateNotNull()]
[ValidateNotNullOrEmpty()]
[PSCustomObject]$inventoryStructure
 # SoftwareConfigurationGroupsInformation help description
, [Parameter(Mandatory = $true,
  Position = 2,
  ValueFromPipeline = $false,
  ValueFromPipelineByPropertyName = $false,
  ValueFromRemainingArguments = $false)
]
[ValidateNotNull()]
[ValidateNotNullOrEmpty()]
[hashtable]$softwareConfigurationGroupsInformation
, # AnsibleGroupName help description
[Parameter(ParameterSetName = 'AnsibleGroupNames',
  Mandatory = $false,
  Position = 3,
  ValueFromPipeline = $false,
  ValueFromPipelineByPropertyName = $false,
  ValueFromRemainingArguments = $false)
]
[ValidateNotNull()]
[ValidateNotNullOrEmpty()]
[string] $AnsibleGroupName

, # hostName help description
[Parameter(ParameterSetName = 'HostNames',
  Mandatory = $false,
  Position = 3,
  ValueFromPipeline = $false,
  ValueFromPipelineByPropertyName = $false,
  ValueFromRemainingArguments = $false)
]
[ValidateNotNull()]
[ValidateNotNullOrEmpty()]
[string] $hostName

)
$parsedInventory = $InventoryStructure.AnsibleInventory

[System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()
$addedParametersScriptblock = {
  param(
    [string[]]$addedParameters
  )
  if ($addedParameters) {
    foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
    # [void]$sbAddedParameters.Append('"')
    $sbAddedParameters.ToString()
    [void]$sbAddedParameters.Clear()
  }
}

[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

$AnsibleGroupNameSpecificPreambleAnsibleGroupNameScriptBlock = {
  switch ($ansibleGroupName) {
    'WindowsHosts' {
      [void]$sb.Append(@"
# Ensure that Chocolatey and the chocolatey package installer are installed
- name: Install Chocolatey
  hosts: all
  gather_facts: false
  tasks:
    - name: Install Chocolatey
      win_chocolatey:
        name: chocolatey
        state: present
    - name: Configure chocolatey cache location
      win_chocolatey_config:
        name: cacheLocation
        state: present
        value: "{{ ChocolateyCacheLocation }}"
    # Configure Chocolatey to allow community packages ()'allowGlobalConfirmation,allowEmptyChecksums,allowEmptyChecksumsSecure,allowInsecureConfirmation,allowMultipleVersions')
    - name: allow Global confirmation when installing packages and their dependencies
      win_chocolatey_feature:
        name: allowGlobalConfirmation
        state: disabled
    # Configure Chocolatey to install community extensions
    - name: Install chocolatey-core.extension
      win_chocolatey:
        name: chocolatey-core.extension
        state: present
    # Install the cChoco Poweshell module
    - name: Ensure the cCHoco module from the PSGallery is present
      community.windows.win_psmodule:
        name: cChoco
        accept_license: true
        repository: PSGallery

  tags: [$ansiblegroupname, Preamble, InstallChocolatey]
"@)
    }
  }
}

$ChocolateyPackagesForAnsibleGroupNameScriptBlock = {
  if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('ChocolateyPackageNames')) { # process for $ansibleGroupName only if the ChocolateyPackageNames key exists
    if ($null -ne $($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ChocolateyPackageNames) {
      [void]$sb.Append(@"

# ChocolateyPackages Per Group
- name: Install the Chocolatey Packages defined for the group '$ansibleGroupName'
  hosts: all
  gather_facts: false
  tasks:
    - name: Install the Chocolatey Packages
      # win_dsc:
      #   resource_name: cChocoPackageInstaller
      #   Name: "{{ item.name }}"
      #   Version: "{{ item.version }}"
      #   Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
      #   Params: "{{ item.AddedParameters if item.AddedParameters else omit }}"
      win_chocolatey:
        name: '{{ item.name }}'
        version: '{{ item.version }}'
        allow_prerelease: "{{ 'True' if (item.AllowPrerelease == 'true') else 'false'}}"
        state: "{{ 'absent' if (action_type == 'Uninstall') else 'present'}}"
        {% if item.AddedParameters is defined and item.AddedParameters|length %}
        'package_params: ' "{{ item.AddedParameters }}"
        {% endif %}
      failed_when: false # Setting this means if one package fails, the loop will continue. You can remove it if you don't want that behaviour.
      loop:

"@
      )
      for ($index = 0; $index -lt @($($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).ChocolateyPackageNames).count; $index++) {
        $packageName = $($($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).ChocolateyPackageNames)[$index]
        $packageVersion = $($($SoftwareConfigurationGroupsInformation.ChocolateySoftwareConfigurationGroupsInformation)[$packageName]).Version
        $allowPrerelease = $($($SoftwareConfigurationGroupsInformation.ChocolateySoftwareConfigurationGroupsInformation)[$packageName]).AllowPrerelease
        $addedParameters = . $addedParametersScriptblock $($($SoftwareConfigurationGroupsInformation.ChocolateySoftwareConfigurationGroupsInformation)[$packageName]).AddedParameters

        [void]$sb.Append("        - {name: $packageName, version: $packageVersion, AllowPrerelease: $allowPrerelease, AddedParameters: $addedParameters}")
        [void]$sb.Append("`n")

      }
      [void]$sb.Append(@"
      when: "'$ansibleGroupName' in group_names "
  tags: [$ansiblegroupname, ChocolateyPackages]
"@)
    }
  }
}

$PowershellModulesForAnsibleGroupNameScriptBlock = {
  # if ($ansibleGroupName -ne 'WindowsHosts' ) { continue } # skip things for development
  if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('PowershellModuleNames')) { # process for $ansibleGroupName only if the PowershellModuleNames key exists
    if ($null -ne $($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).PowershellModuleNames) {
      [void]$sb.Append(@"

# Powershell Modules per Group
- name: Install Powershell modules For $ansibleGroupName
  hosts: all
  gather_facts: false
  tasks:

    - name: Install the modules defined for each group
      community.windows.win_psmodule:
        name: "{{ item.name }}"
        state: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
        version: "{{ item.version }}"
        allow_prerelease: "{{ item.AllowPrerelease }}"
      loop:

"@)
      for ($index = 0; $index -lt @($($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).PowershellModuleNames).count; $index++) {
        $moduleName = $($($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).PowershellModuleNames)[$index]
        $moduleVersion = $($($SoftwareConfigurationGroupsInformation.PowershellModuleInfos)[$moduleName]).Version
        $allowPrerelease = $($($SoftwareConfigurationGroupsInformation.PowershellModuleInfos)[$moduleName]).AllowPrerelease
        [void]$sb.Append("        - {name: $moduleName, version: $moduleVersion, AllowPrerelease: $allowPrerelease  }")
        [void]$sb.Append("`n")
      }
      [void]$sb.Append(@"
      when: "'$ansibleGroupName' in group_names "
  tags: [$ansiblegroupname, PowershellModules]
"@)
    }
  }
}

$RegistrySettingsForAnsibleGroupNameScriptBlock = {
  # if($ansibleGroupName -ne 'WindowsHosts' ) {continue} # skip things for development
  if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('RegistrySettingsNames')) { # process for $ansibleGroupName only if the RegistrySettingsNames key exists
    if ($null -ne $($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).RegistrySettingsNames) {
      [void]$sb.Append(@"

# Registry Settings per Group
- name: Install Registry Settings For $ansibleGroupName
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
      for ($index = 0; $index -lt @($($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).RegistrySettingsNames).count; $index++) {
        [void]$sb.Append('          - ' + @($($($parsedInventory.AnsibleGroupNames)[$ansibleGroupName]).RegistrySettingsNames)[$index])
        [void]$sb.Append("`n")
      }
      [void]$sb.Append(@"
      when: "'$ansibleGroupName' in group_names"
  tags: [$ansiblegroupname,RegistrySettings]
"@)
    }
  }
}
#state: "{{ registry_properties[item]['state']|default( {{ 'Absent' if (action_type == 'Uninstall') else 'Present'}} ) }}"

$RolesForAnsibleGroupNameScriptBlock = {
  # if($ansibleGroupName -ne 'WindowsHosts' ) {continue} # skip things for development
  if ($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).ContainsKey('AnsibleRoleNames')) { # process for $ansibleGroupName only if the AnsibleRoleNames key exists
    if ($null -ne $($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).AnsibleRoleNames) {
      # playbooks are in the $basedirectory/playbooks, while roles are in basedirectory/roles. But roles are searched below the playbooks dir. So to find a role, requires a custom role path, ""../roles/""
      [void]$sb.Append(@"

# Roles per Group
- name: Install roles For $ansibleGroupName
  hosts: all
  gather_facts: false
  tasks:
    - name: Include the following role on all the hosts in $ansibleGroupName
      include_role:
        name: "{{ roleItem }}"
      loop:

"@)
      $roleNames = @($($parsedInventory.AnsibleGroupNames[$ansibleGroupName]).AnsibleRoleNames)
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
      when: "'$ansibleGroupName' in group_names "

"@)
      # $roleNamesStr = $roleNames -join ',' # $roleNamesStr,
      [void]$sb.Append(@"
  tags: [$ansiblegroupname,Roles]
"@)
    }
  }
}

function Contents {
  $(if ($true) { $(. $AnsibleGroupNameSpecificPreambleAnsibleGroupNameScriptBlock ) })

  $(if ($true) { $(. $ChocolateyPackagesForAnsibleGroupNameScriptBlock) })

  $(if ($true) { $(. $PowershellModulesForAnsibleGroupNameScriptBlock) })

  $(if ($true) { $(. $RegistrySettingsForAnsibleGroupNameScriptBlock) })

  $(if ($true) { $(. $RolesForAnsibleGroupNameScriptBlock) })
}

[void]$sb.Append($($template -replace '\{2}', "ansiblegroupname $ansibleGroupName"))
[void]$sb.Append("`n")

#$ymlContents = $template -replace '\{2}', "ansiblegroupname $ansibleGroupName"
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
#     msg: "hostvars are {{ hostvars[inventory_hostname] }} ansibleGroupNameis {{ item }}  }} "
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

