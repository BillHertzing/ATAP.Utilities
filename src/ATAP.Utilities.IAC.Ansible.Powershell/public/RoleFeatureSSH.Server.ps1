
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames
  , [string] $name
  , [string] $version

)

function ContentsTask {

  return @'
- name: Get Info about SSH Server
  ansible.windows.win_powershell:
  executable: pwsh.exe
  script: |- name: set chocolatey configuration
  win_dsc:
    resource_name: cChocoConfig
    ConfigName: 'cacheLocation'
    Value: 'C:\Temp\chocotesting\cache'
    Ensure: Present

    $Ansible.result =
      $('ABC') | ConvertTo-Json -Depth 99
  register: fullresults
  failed_when: fullresults.error | length > 0
  when:  "action_type == 'Check'"

- name: show returned information
  debug:
    var: fullresults
  ignore_errors: yes
'@
}
function ContentsVars {
@"
version: Dummy
allow_prerelease: false
"@
}

# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^handlers|defaults|meta|files|templates|library|module_utils|lookup_plugins|scripts$'
$subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
  $roleSubdirectoryName = $subDirectoriesToBuild[$index]
  $roleSubdirectoryPath = $(Join-Path $roleDirectoryPath $roleSubdirectoryName)
  New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  $ymlContents = $($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', "RoleFeature$roleName"
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

