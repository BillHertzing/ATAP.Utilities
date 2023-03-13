# The script that creates the Jenkins Controller Role
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames

)

$addedParametersScriptblock = { if ($addedParameters) {
    # [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    # [void]$sb.Append('Params: "')
    # foreach ($ap in $addedParameters) { [void]$sb.Append("/$ap ") }
    # [void]$sb.Append('"')
    # $sb.ToString()
  }
}

function ContentsTask {
  @"

- name: Install or Uninstall Java Service Account User
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: "{{ JREName }}"
    Version: "{{ JREVersion }}"
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"

- name: Install or Uninstall Java JRE using chocolatey
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: "{{ JREName }}"
    Version: "{{ JREVersion }}"
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    $(. $addedParametersScriptblock)


- name: install or uninstall jenkins using chocolatey
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: "{{ JenkinsName }}"
    Version: "{{ JenkinsVersion }}"
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    $(. $addedParametersScriptblock)
"@
}

function ContentsVars {
  @"
JREName: temurin17jre
JREVersion: 17.0.6.1000
JREAllow_prerelease: false
JenkinsName: jenkins
JenkinsVersion: 2.387.1
JenkinsAllow_prerelease: false
"@
}

function ContentsMeta {
  @'
dependencies:
  # - role: RoleChocolateyInstallAndConfigure
'@
}

# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^handlers|defaults|files|templates|library|module_utils|lookup_plugins|scripts$'
$subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
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
    '^meta$' {
      $ymlContents += ContentsMeta
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $ymlContents
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }
}

 # name of JRE package should be a parameter
 # version of JRE package should be a parameter
