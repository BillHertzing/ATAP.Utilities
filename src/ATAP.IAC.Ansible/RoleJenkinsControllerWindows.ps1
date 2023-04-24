# The script that creates the Jenkins Controller Role
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames

)

# use a unique local StringBuilder for each file
[System.Text.StringBuilder]$sbMeta = [System.Text.StringBuilder]::new()
[System.Text.StringBuilder]$sbDefaults = [System.Text.StringBuilder]::new()
[System.Text.StringBuilder]$sbVars = [System.Text.StringBuilder]::new()
[System.Text.StringBuilder]$sbTasks = [System.Text.StringBuilder]::new()


$addedParametersScriptblock = {param([string[]]$addedParameters) if ($addedParameters) {
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('Params: "')
    foreach ($ap in $addedParameters) { [void]$sb.Append("/$ap ") }
    [void]$sb.Append('"')
    $sb.ToString()
  }
}

function ContentsMeta {
  [void]$sbMeta.Append(@"
author: William Hertzing for ATAP.org
description: Ansible role to setup a Jenkins Windows Controller installed as a service via Chocolatey
attribution:
company: ATAP.org
role_name: JenkinsControllerWindows
license: license (MIT)
min_ansible_version: 2.4
dependencies: []
"@)
}

function ContentsDefaults {
  [void]$sbDefaults.Append(@"
  ServiceAccountName: $($global:settings[$global:configRootKeys['JenkinsControllerServiceAccountConfigRootKey']])
  ServiceAccountFullname: Jenkins Controller Service Account
  ServiceAccountDescription: User under which the Jenkins Controller Windows service runs
  # groups:
  ServiceAccountPasswordFromAnsibleVault : insecure
  ServiceAccountUserHomeDirectory: C:\\Users\\$($global:settings[$global:configRootKeys['JenkinsControllerServiceAccountConfigRootKey']])

  ServiceAccountPowershellCoreProfileSource: '/mnt/c/dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Powershell/profiles/ProfileForServiceAccountUsers.ps1'
  ServiceAccountPowershellDesktopProfileSource: '/mnt/c/dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Powershell/profiles/ProfileForServiceAccountUsers.ps1'

  ChocolateyPackageName: jenkins
  InstallationDirectory:
  JenkinsRootDirectory:
  Port

"@)
}
function ContentsVars {
  [void]$sbVars.Append(@"

  ServiceAccountPowershellCoreProfileSource: '/mnt/c/dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Powershell/profiles/ProfileForServiceAccountUsers.ps1'
  ServiceAccountPowershellDesktopProfileSource: '/mnt/c/dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Powershell/profiles/ProfileForServiceAccountUsers.ps1'

  ChocolateyPackageVersion: 2.387.1
  ChocolateyPackageAllow_prerelease: false
"@)
}

function ContentsTask {
  # ToDo grant Login and LoginAsAService rights to the user
  # ToDo: set a password expiry duration, anbd write a play/playbook to update the password for the Jenkins Agent Service Account User
  # ToDO: support for pre-release version of ChocolateyPackage
  # ToDo: support for specific log file for the chocolatey package installation process
  # ToDo: installation arguments for the controller
  #  /InstallDir
  #  /Jenkins_Root
  #  /Port
  #  /Java_Home
  #  /Service_Username
  #  /Service_Password
  [void]$sbTasks.Append(@"

- name: Install or Uninstall Jenkins Controller Service Account User
  ansible.windows.win_user:
    name: "{{ ServiceAccountName }}"
    fullname: "{{ ServiceAccountFullname }}"
    description: "{{ ServiceAccountDescription }}"
    password: "{{ ServiceAccountPasswordFromAnsibleVault }}"
    groups:
    - "JenkinsControllers"
    password_never_expires: true
    account_disabled: false

- name: Create or Delete a home directory for the Jenkins Controller Service Account User
  ansible.windows.win_file:
    path: "{{ ServiceAccountUserHomeDirectory }}"
    state: directory

- name: Manage Jenkins Controller Service Account User Home Directory Permissions
  win_acl:
    path: "{{ ServiceAccountUserHomeDirectory }}"
    propagation: "InheritOnly"
    rights: "FullControl"
    type: "allow"
    user: "{{ ServiceAccountName }}"

- name: Create or Delete a Powershell (Core) subdirectory for the Jenkins Controller Service Account User
  ansible.windows.win_file:
    path: "{{ ServiceAccountUserHomeDirectory }}\\Powershell"
    state: directory

- name: Create or Delete a Powershell (Desktop) subdirectory for the Jenkins Controller Service Account User
  ansible.windows.win_file:
    path: "{{ ServiceAccountUserHomeDirectory }}\\WindowsPowershell"
    state: directory

- name: Install or Uninstall Jenkins Controller Service Account User's Powershell Core profile
  win_copy:
    src: "{{ ServiceAccountPowershellCoreProfileSource }}"
    dest: "{{ ServiceAccountUserHomeDirectory }}\\Powershell\\profile.ps1"

- name: Install or Uninstall Jenkins Controller Service Account User's Powershell Desktop profile
  win_copy:
    src: "{{ ServiceAccountPowershellDesktopProfileSource }}"
    dest: "{{ ServiceAccountUserHomeDirectory }}\\WindowsPowershell\\profile.ps1"

- name: Install or Uninstall Jenkins Controller using chocolatey
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: "{{ ChocolateyPackageName }}"
    Version: "{{ ChocolateyPackageVersion }}"
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    $(. $addedParametersScriptblock(@('PORT=8081','INSTALLDIR=D:\TEMP\JenkinsControllerInstallDir','JENKINS_ROOT=D:\TEMP\JenkinsControllerRoot')))

# Note that the Jenkins_Home environment variable is set via the Jenkins Controller Service Account's user profile

"@)
}


# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^handlers|defaults|files|templates|library|module_utils|lookup_plugins|scripts$'
$subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
  $roleSubdirectoryName = $subDirectoriesToBuild[$index]
  $roleSubdirectoryPath = $(Join-Path $roleDirectoryPath $roleSubdirectoryName)
  New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  $introductoryStanza = $($($ymlGenericTemplate -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName)
  switch -regex ($roleSubdirectoryName) {
    '^meta$' {
      [void]$sbMeta.AppendLine($introductoryStanza)
      ContentsMeta
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sbMeta.ToString()
    }
    '^defaults$' {
      [void]$sbDefaults.AppendLine($introductoryStanza)
      ContentsDefaults
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value  $sbDefaults.ToString()
    }
    '^vars$' {
      [void]$sbVars.AppendLine($introductoryStanza)
      ContentsVars
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sbVars.ToString()
    }
    '^tasks$' {
      [void]$sbTasks.AppendLine($introductoryStanza)
      ContentsTask
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sbTasks.ToString()
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }
}

