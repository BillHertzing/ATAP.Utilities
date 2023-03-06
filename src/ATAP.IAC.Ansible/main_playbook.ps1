# Define the main playbook
param (
  [string] $ymlGenericTemplate
  , [string] $Path
  ,[hashtable] $parsedInventory
)

$playScriptblock = {
param ([hashtable]$play)
@"
- name: Run roles for $($play.GroupName)
  hosts: $($play.GroupName)
  become: true
  gather_facts: false
  tasks:
    - name: Run the following roles on all the $($play.GroupName)
      include_role:
        name: "{{ item }}"
      loop:
$( $lines = @(); $play.items|ForEach-Object{$lines += $("        - " + $_)}; $lines -join "`n" )

"@
}

$packagePlaysScriptBlock =  {
  $lines = @()
  $parsedInventory.RoleNamesForPackages.Keys | ForEach-Object {
    $lines += $(& $playScriptblock @{GroupName=$_;items=$parsedInventory.RoleNamesForPackages[$_]})
    $lines += "`n"
  }
  $lines
}

$modulePlaysScriptBlock =  {
  $lines = @()
  $parsedInventory.RoleNamesForModules.Keys | ForEach-Object {
    $lines += $(& $playScriptblock @{GroupName=$_;items=$parsedInventory.RoleNamesForModules[$_]})
    $lines += "`n"
  }
  $lines
}

function Contents {
  param(
    [string] $name
  )
  # $parsedInventory is a hashtable that specifies all the roles and modules for all the groups
@"
- name: Top Play
  hosts: all
  gather_facts: false
  tasks:
    - name: Print action_type variable
      debug:
        var: action_type

$(. $modulePlaysScriptBlock)

$(. $packagePlaysScriptBlock)
"@
}

  $ymlContents= $ymlGenericTemplate -replace '\{2}', 'Main Playbook'

  # ToDo: get the formatting correct, so that we don't have to run this global search and replace
  $ymlContents += $($($(Contents) -split "`n") | ForEach-Object{$_ -replace '^\s{0,1}-', '-'}) -join "`n"
  Set-Content -Path $Path -Value $ymlContents


        # - 'JenkinsClient'

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

