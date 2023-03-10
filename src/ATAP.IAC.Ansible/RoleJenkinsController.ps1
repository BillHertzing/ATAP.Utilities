# The script that creates the Jenkins Controller Role
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
    # [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    # [void]$sb.Append('Params: "')
    # foreach ($ap in $addedParameters) { [void]$sb.Append("/$ap ") }
    # [void]$sb.Append('"')
    # $sb.ToString()
  }
}

function ContentsTask {
  @"
- name: install or uninstall jenkins
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: 'jenkins'
    Version: "{{ version }}""
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    $(. $addedParametersScriptblock)
"@
}

function ContentsVars {
  @"
version: $version
allow_prerelease: false
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

