# The script that creates the Jenkins Controller Role
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames

)

# use a local $sb to build up the files' contents
[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
[System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()

$addedParametersScriptblock = {
  param(
    [string[]]$addedParameters
  )
  if ($addedParameters) {
    [void]$sbAddedParameters.Append('"')
    foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
    [void]$sbAddedParameters.Append('"')
    $sbAddedParameters.ToString()
    [void]$sbAddedParameters.Clear()
  }
}

function ContentsTask {
  [void]$sb.Append(@'
- name: Install or Uninstall Java JRE using chocolatey
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: "{{ item.name }}"
    Version: "{{ item.version }}"
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    Params: "{{ item.AddedParameters if item.AddedParameters else omit }}"
  loop:

'@)

  $packageName = 'temurin17jre'
  $packageVersion = '17.0.6.1000'
  $allowPrerelease = $false
  $addedParameters = . $addedParametersScriptblock @('ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome', 'ch') # {{ ProgramFiles }}{{ JavaInstallDirRelativeSubdirectory }}
  [void]$sb.AppendLine("      - {name: $packageName, version: $packageVersion, AllowPrerelease: $allowPrerelease, AddedParameters: $addedParameters}")
  [void]$sb.Append(@"
  tags: [$roleName]
  ignore_errors: yes
"@)
}

function ContentsMeta {
  [void]$sb.Append(@'
galaxy_info:
  author: William Hertzing for ATAP.org
  description: Ansible role to install the Java Runtime Environment (JRE) software onto a Windows Host
  attribution:
  company: ATAP.org
  role_name: JavaInterpreterWindows
  license: license (MIT)
  min_ansible_version: 2.4
  dependencies: []
'@)
}

# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^handlers|defaults|files|templates|library|module_utils|lookup_plugins|scripts|vars$'
$subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
  $roleSubdirectoryName = $subDirectoriesToBuild[$index]
  $roleSubdirectoryPath = $(Join-Path $roleDirectoryPath $roleSubdirectoryName)
  New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  $introductoryStanza = $($($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName)
  [void]$sb.Clear()
  [void]$sb.AppendLine($introductoryStanza)
switch -regex ($roleSubdirectoryName) {
    '^tasks$' {
      ContentsTask
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
    }
    # '^vars$' {
    #   [void]$sbVars.AppendLine(introductoryStanza)
    #   ContentsVars
    #   Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sbVars.ToString()
    # }
    '^meta$' {
      ContentsMeta
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }
}
