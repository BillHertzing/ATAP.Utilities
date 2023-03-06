
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames
  , [string] $name
  , [string] $version
  , [string[]] $addedParameters

)

$addedParametersScriptblock = { if ($addedParameters) {
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('Params: "')
    foreach ($ap in $addedParameters) { [void]$sb.Append("/$ap ") }
    [void]$sb.Append('"')
    $sb.ToString()
  }
}

function ContentsTask {

  return @"
- name: install or uninstall an exact version of PowerShell module
  community.windows.win_psmodule:
    name: '$name'
    required_version: '{{ version }}'
    allow_prelease: '{{ allowPrelease }}'
    state: "{{ 'absent' if (action_type == 'Uninstall') else 'present'}}"
    $(. $addedParametersScriptblock)
"@
}
function ContentsVars {

  return @"
version: $version

"@
}

# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^(handlers|defaults|meta|files|templates|library|module_utils|lookup_plugins|scripts)$'
$subDirectoriesToBuild = $roleSubdirectoryNames -notmatch $excludedSubDirectoriesPattern  # minus the excluded ones
for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
  $roleSubdirectoryName = $subDirectoriesToBuild[$index]
  $roleSubdirectoryPath = $(Join-Path $roleDirectoryPath $roleSubdirectoryName)
  New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  $ymlContents = $($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName
  switch -regex ($roleSubdirectoryName) {
    '^tasks$' {
      $ymlContents += ContentsTask
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $ymlContents
    }
    '^vars$' {
      $ymlContents += ContentsVars
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $ymlContents
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }

}

if ($false) {


}

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

