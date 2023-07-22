# The script that creates the WinSW Role
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames

)

# use a local StringBuilder for all file
[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
[System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()

# $addedParametersScriptblock = {
#   param(
#     [string[]]$addedParameters
#   )
#   if ($addedParameters) {
#     [void]$sbAddedParameters.Append('Params: "')
#     foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
#     [void]$sbAddedParameters.Append('"')
#     $sbAddedParameters.ToString()
#     [void]$sbAddedParameters.Clear()
#   }
# }

function ContentsMeta {
  [void]$sb.Append(@'
galaxy_info:
  author: William Hertzing for ATAP.org
  description: Ansible role to install the WinSW software, which among other things can run a Java application as a service
  attribution:
  company: ATAP.org
  role_name: WinSW
  license: license (MIT)
  min_ansible_version: 2.4
  dependencies: []
'@)
}


function ContentsTask {
  [void]$sb.Append(@"
- name: Check if the WinSW already exists locally
  win_stat:
    path: "{{ $($global:configRootKeys['WinSWInternalDestinationPathConfigRootKey']) }}"
  register: WinSWExistsLocally

- name: copy the WinSW locally unless it already exists locally
  block:
  - name: Create the directory structure for the WinSWInternalDestinationDirectory
    win_file:
      path: "{{ $($global:configRootKeys['WinSWInternalDestinationDirectoryConfigRootKey']) }}"
      state: directory
    when: not WinSWExistsLocally.stat.exists

  - name: Download the WinSW from the WinSWPublicURL if it does not exist locally
    win_get_url:
      url: "{{ $($global:configRootKeys['WinSWPublicURLConfigRootKey']) }}"
      dest: "{{ $($global:configRootKeys['WinSWInternalDestinationPathConfigRootKey']) }}"
    when: not WinSWExistsLocally.stat.exists

"@)
}

# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^(defaults|files|handlers|library|lookup_plugins|module_utils|scripts|templates|vars)$'
$subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
  $roleSubdirectoryName = $subDirectoriesToBuild[$index]
  $roleSubdirectoryPath = $(Join-Path $roleDirectoryPath $roleSubdirectoryName)
  New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  $introductoryStanza = $($($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName)
  [void]$sb.Clear()
  [void]$sb.Append($introductoryStanza)
  [void]$sb.Append("`n")

  switch -regex ($roleSubdirectoryName) {
    '^meta$' {
      ContentsMeta
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
    }
    '^templates$' {
      ContentsTemplates
      Set-Content -Path "$roleSubdirectoryPath\service.yml" -Value $sb.ToString()
    }
    '^tasks$' {
      ContentsTask
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }
}

