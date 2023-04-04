# The script that creates the role that installs and configures chocolatey
param (
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames
)

function ContentsTask {
  # The value comes from the TMPDIR on the remote hosts
  @"
  - name: ensure Chocolatey is installed
    win_chocolatey:
      name: chocolatey
      state: present

  - name: set chocolatey configuration
    win_dsc:
      resource_name: cChocoConfig
      ConfigName: 'cacheLocation'
      Value: "{{ ChocolateyCacheLocation }}"
      Ensure: Present
"@
}

function ContentsVars {
@"
# So that all users share the location, this is a common location. It can and often is overwritten in the host_vars
ChocolateyCacheLocation: 'C:\Temp\chocolatey\cache'
"@
}

# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^handlers|defaults|meta|files|templates|library|module_utils|lookup_plugins|scripts$'
$subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
  $roleSubdirectoryName = $subDirectoriesToBuild[$index]
  $roleSubdirectoryPath = $(Join-Path $roleDirectoryPath $roleSubdirectoryName)
  New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  $ymlContents = $($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName
  switch -regex ($roleSubdirectoryName) {
    '^tasks$' {
      $ymlContents += $(ContentsTask -split "`r`n") -join "`n"
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $ymlContents
    }
    '^vars$' {
      $ymlContents += $(ContentsVars -split "`r`n") -join "`n"
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $ymlContents
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }
}


    # '^scripts$' {
    #   $scriptName = $roleName + 'Script.ps1'
    #   $scriptSourcePath = "./$scriptName"
    #   $scriptDestinationPath = join-path $roleSubdirectoryPath $scriptName
    #   Copy-Item -Path $scriptSourcePath -Destination $scriptDestinationPath
    # }


#   - name: Print action_type variable
#   debug:
#     var: action_type

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
    #     msg: "hostvars are {{ hostvars[inventory_hostname] }} groupname is {{ item }}  }} "
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

        # - name: Get all roles assigned to host's groups
    #   set_fact:
    #     all_roles: "{{ all_roles|default([]) + item.roles|default([]) }}"
    #   loop: "{{ hostvars[inventory_hostname].group_names }}"
    #   vars:
    #     item_roles: "{{ vars[item]['roles']|default([]) }}"
    #   when: item_roles|length > 0
