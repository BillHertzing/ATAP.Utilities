# The script that creates the Ruby Interpreter Role
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames

)

# use a local $sb for each file type
[System.Text.StringBuilder]$sbTask = [System.Text.StringBuilder]::new()
[System.Text.StringBuilder]$sbVars = [System.Text.StringBuilder]::new()
[System.Text.StringBuilder]$sbMeta = [System.Text.StringBuilder]::new()

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
  [void]$sbTask.Append(@"

- name: Install or Uninstall Ruby using chocolatey
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: "{{ RubyName }}"
    Version: "{{ RubyVersion }}"
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    $(. $addedParametersScriptblock)
  tags: [$roleName]
"@)
# ToDo Fix AddedParameters for chocolatey installation
}

function ContentsVars {
  [void]$sbVars.Append(@"
RubyName: ruby
RubyVersion: 3.1.3.1
RubyAllow_prerelease: false
"@)
# ToDo Fix AddedParameters for chocolatey installation
}

function ContentsMeta {
  [void]$sbMeta.Append(@"
dependencies:
  # - role: RoleChocolateyInstallAndConfigure
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
      [void]$sbTask.AppendLine($($($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
      ContentsTask
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sbTask.ToString()
    }
    '^vars$' {
      [void]$sbVars.AppendLine($($($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
      ContentsVars
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sbVars.ToString()
    }
    '^meta$' {
      [void]$sbMeta.AppendLine($($($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
      ContentsMeta
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sbMeta.ToString()
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }
}
