
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames
  , [string] $name
  , [string] $version
  , [string[]] $addedParameters

)

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
$excludedSubDirectoriesPattern = '^(handlers|defaults|files|templates|library|module_utils|lookup_plugins|scripts)$'
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

