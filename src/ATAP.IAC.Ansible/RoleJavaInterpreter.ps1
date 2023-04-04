# The script that creates the Jenkins Controller Role
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

# ToDo Fix AddedParameters for chocolatey installation
$addedParametersScriptblock = { if ($addedParameters) {
    # [void]$sb.Append('Params: "')
    # foreach ($ap in $addedParameters) { [void]$sb.Append("/$ap ") }
    # [void]$sb.Append('"')
  }
}

function ContentsTask {
  [void]$sbTask.Append(@"

- name: Install or Uninstall Java JRE using chocolatey
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: "{{ JREName }}"
    Version: "{{ JREVersion }}"
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    $(. $addedParametersScriptblock)
  tags: [$roleName]
"@)
# ToDo Fix AddedParameters for chocolatey installation
}

function ContentsVars {
  [void]$sbVars.Append(@"
JREName: temurin17jre
JREVersion: 17.0.6.1000
JREAllow_prerelease: false
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
