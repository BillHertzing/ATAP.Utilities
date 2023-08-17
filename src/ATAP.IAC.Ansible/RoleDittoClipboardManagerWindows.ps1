

$TaskScriptblock = {

  [void]$sb.Append(@"
  - name: install the chocolatey packages
    win_chocolatey:
  	name: '{{ item.name }}'
  	# version: '{{ item.version }}'
  	allow_prerelease: "{{ 'true' if (item.allowprerelease == 'true') else 'false'}}"
  	state: "{{ 'absent' if (action_type == 'uninstall') else 'present'}}"
  	# {% if item.addedparameters is defined and item.addedparameters|length %}
  	# 'package_params: ' "{{ item.addedparameters }}"
  	# {% endif %}
    failed_when: false # setting this means if one package fails, the loop will continue. you can remove it if you don't want that behaviour.
    loop:
  	- {name: ditto, version: latest, allowprerelease: false, addedparameters: "InstallDir:'C:\Program Files\PythonInterpreters\Python3.10.11" }
  tags: [$roleName]
  ignore_errors: yes
  - name: set registry values per user
    win_regedit:
      path: "{{ item.path }}"
      name: "{{ item.name }}"
      data: "{{ item.data|default(none) }}"
      type: "{{ item.type|default('dword') }}"
    loop:
      - {path: HKCU:\Software\Ditto, name: NetworkStringPassword, data: "LetMeIn", type: SZ}
      - {path: HKCU:\Software\Ditto, name: CustomSendToList2, data: "<CustomFriends> </CustomFriends>", type: SZ}
      # ToDo - loop over all host names that are memners of the  UIHost AnsibleGroup
      - {path: HKCU:\Software\Ditto, name: sendclient_ip_0, data: "utat01", type: SZ}
      - {path: HKCU:\Software\Ditto, name: sendclient_autosend_0, data: "1", type: dword}

        # set-itemproperty HKCU:\Software\Ditto -Name DBPath3 -value "{{ $($global:configRootKeys['DittoDBPathConfigRootKey'])}}'"
  tags: [$roleName]
  ignore_errors: yes
"@)
}

$VarScriptblock = {

[void]$sb.Append(@"
$global:configRootKeys['DittoDBPathConfigRootKey']: $global:settings[$($global:configRootKeys['DittoDBPathConfigRootKey'])]

"@)
}

$MetaScriptblock = {
  [void]$sb.Append(@"
galaxy_info:
  author: William Hertzing for ATAP.org
  description: Ansible role to install Ditto via Chocolatey and configure it
  attribution:
  company: ATAP.org
  role_name: $rolename
  license: license (MIT)
  min_ansible_version: 2.4
  dependencies: []
"@)
  }
