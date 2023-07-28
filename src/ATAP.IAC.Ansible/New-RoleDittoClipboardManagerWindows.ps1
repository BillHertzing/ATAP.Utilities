# The script that creates the Ditto Clipboard Manager Role
function New-RoleDittoClipboardManagerWindows {
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames

)

# use a local StringBuilder
[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

[System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()

$addedParametersScriptblock = {
  param(
    [string[]]$addedParameters
  )
  if ($addedParameters) {
    [void]$sbAddedParameters.Append('Params: "')
    foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
    [void]$sbAddedParameters.Append('"')
    $sbAddedParameters.ToString()
    [void]$sbAddedParameters.Clear()
  }
}

function ContentsTask {
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
	  # ditto
		- {name: choco install ditto, version: latest, allowprerelease: false, addedparameters: "InstallDir:'C:\Program Files\PythonInterpreters\Python3.10.11" } 
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
      - {path: HKCU:\Software\Ditto, name: sendclient_ip_0, data: "utat01", type: SZ} 
      - {path: HKCU:\Software\Ditto, name: sendclient_autosend_0, data: "1", type: dword} 
        
        # BasePath depends on the host and the gobal settings
        # $basepath = $(HostSettings[$hostname])['DropboxBasePath']
        # set-itemproperty HKCU:\Software\Ditto -Name DBPath3 -value "'$basepath\Ditto\$($hostname)_ditto.db'"
  tags: [$roleName]
  ignore_errors: yes
"@)
}

function ContentsVars {
  [void]$sb.Append(@"
TBD: tbd
"@)
# ToDo Fix AddedParameters for chocolatey installation
}

function ContentsMeta {
  [void]$sb.Append(@"
galaxy_info:
  author: William Hertzing for ATAP.org
  description: Ansible role to setup a Python Interpreter via Chocolatey
  attribution:
  company: ATAP.org
  role_name: PythonInterpreterWindows
  license: license (MIT)
  min_ansible_version: 2.4
  dependencies: []
"@)
}

# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^handlers|defaults|files|templates|library|module_utils|lookup_plugins|scripts$'
$subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
  $roleSubdirectoryName = $subDirectoriesToBuild[$index]
  $roleSubdirectoryPath = $(Join-Path $roleDirectoryPath $roleSubdirectoryName)
  New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  switch -regex ($roleSubdirectoryName) {
    '^tasks$' {
      [void]$sb.AppendLine($($($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
      ContentsTask
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
	  [void]$sb.Clear()
    }
    '^vars$' {
      [void]$sb.AppendLine($($($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
      ContentsVars
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
	  [void]$sb.Clear()
    }
    '^meta$' {
      [void]$sb.AppendLine($($($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
      ContentsMeta
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
	  [void]$sb.Clear()
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }
}
}
