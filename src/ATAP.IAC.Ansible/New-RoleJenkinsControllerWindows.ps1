# The script that creates the Jenkins Controller Role
param(
  [string] $ymlGenericTemplate
  , [string] $roleDirectoryPath
  , [string] $roleName
  , [string[]] $roleSubdirectoryNames

)

# use a local StringBuilder
[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
[System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()

$addedParametersScriptblock = {
  param(
    [string[]]$addedParameters
  )
  if ($addedParameters) {
    [void]$sbAddedParameters.Append("'")
    foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
    [void]$sbAddedParameters.Append("'")
    $sbAddedParameters.ToString()
    [void]$sbAddedParameters.Clear()
  }
}

function ContentsMeta {
  [void]$sb.Append(@'
galaxy_info:
  author: William Hertzing for ATAP.org
  description: Ansible role to setup a Jenkins Windows Controller installed as a service via Chocolatey
  attribution:
  company: ATAP.org
  role_name: JenkinsControllerWindows
  license: license (MIT)
  min_ansible_version: 2.4
  dependencies: []
'@)
}


function ContentsVars {
  [void]$sb.Append(@'

  ServiceAccountPowershellCoreProfileSourcePath: '/mnt/c/dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Powershell/profiles/ProfileForServiceAccountUsers.ps1'
  ServiceAccountPowershellDesktopProfileSourcePath: '/mnt/c/dropbox/whertzing/GitHub/ATAP.Utilities/src/ATAP.Utilities.Powershell/profiles/ProfileForServiceAccountUsers.ps1'

'@)
}

function ContentsTask {
  # ToDo grant Login and LoginAsAService rights to the user
  # ToDo: set a password expiry duration, anbd write a play/playbook to update the password for the Jenkins
  # ToDO: support for pre-release version of ChocolateyPackage
  # ToDo: support for specific log file for the chocolatey package installation process
  # ToDo: installation arguments for the controller
  #  /InstallDir
  #  /Jenkins_Root
  #  /Port
  #  /Java_Home
  #  /Service_Username
  #  /Service_Password
  [void]$sb.Append(@"


- name: Install the Jenkins Controller Service Account User, it's user directory, ACL permissions on the user directory, and Powershell Core and Desktop profiles
  block:
  - name: Call the Create-ServiceAccount.ps1 script found in the ATAP.Utilities.Buildtooling.Powershell module
    ansible.windows.win_powershell:
      executable: pwsh.exe
      script: |
        # Import-module  ATAP.Utilities.BuildTooling.Powershell
        . "D:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Create-ServiceAccount.ps1"
        Create-ServiceAccount -ServiceAccount "{{ $($global:configRootKeys['JenkinsControllerServiceAccountConfigRootKey']) }}" -ServiceAccountPasswordKey "{{ $($global:configRootKeys['JenkinsControllerServiceAccountPasswordKeyConfigRootKey']) }}" -ServiceAccountFullname "{{ $($global:configRootKeys['JenkinsControllerServiceAccountFullnameConfigRootKey']) }}" -ServiceAccountDescription "'{{ $($global:configRootKeys['JenkinsControllerServiceAccountDescriptionConfigRootKey']) }}'" -ServiceAccountUserHomeDirectory "{{ $($global:configRootKeys['JenkinsControllerServiceAccountUserHomeDirectoryConfigRootKey']) }}" -ServiceAccountPowershellDesktopProfileSourcePath "{{ $($global:configRootKeys['JenkinsControllerServiceAccountPowershellDesktopProfileSourcePathConfigRootKey']) }}" -ServiceAccountPowershellCoreProfileSourcePath "{{ $($global:configRootKeys['JenkinsControllerServiceAccountPowershellCoreProfileSourcePathConfigRootKey']) }}" -State "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    register: CreateServiceAccountResultOutput

  - name: Parse the returned JSON string into a JSON object
    set_fact:
      CreateServiceAccountResultObject: "{{ CreateServiceAccountResultOutput.result | from_yaml }}"

  - name: Debug output
    debug:
      var: CreateServiceAccountResultObject

# - name: Manage Jenkins Controller Service Account User Home Directory Permissions
#   win_acl:
#     path: "{{ ServiceAccountUserHomeDirectory }}"
#     propagation: "InheritOnly"
#     rights: "FullControl"
#     type: "allow"
#     user: "{{ ServiceAccountName }}"


  - name: Install or Uninstall Jenkins Controller using chocolatey
    win_dsc:
      resource_name: cChocoPackageInstaller
      Name: "{{ item.name }}"
      Version: "{{ item.version }}"
      Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
      Params: "{{ item.AddedParameters if item.AddedParameters else omit }}"
    loop:

"@)

  $packageName = 'jenkins'
  $packageVersion = '2.387.2'
  $allowPrerelease = $false
  # ToDo: lookup the password from a vault using the passwordKey
  $ServiceUsernameParam = "Service_Username=""{{ $($global:configRootKeys['JenkinsControllerServiceAccountConfigRootKey']) }}"""
  $ServicePasswordParam = "Service_Password=""{{ $($global:configRootKeys['JenkinsControllerServiceAccountPasswordKeyConfigRootKey']) }}"""
  $addedParameters = . $addedParametersScriptblock @('PORT=8081','INSTALLDIR=''''C:/Program Files/JenkinsController2''''','JENKINS_ROOT=''''D:/Dropbox/JenkinsControllerRoot2''''',   $ServiceUsernameParam, $ServicePasswordParam)

  [void]$sb.AppendLine("      - {name: $packageName, version: $packageVersion, AllowPrerelease: $allowPrerelease, AddedParameters: $addedParameters}")
  [void]$sb.Append(@"

  # Note that the Jenkins_Home environment variable is set via the Jenkins Controller Service Account's user profile
  # If the host is the Active JenkinsController, set the appropriate environment variables
  tags: [$roleName]

"@)
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
    '^meta$' {
      ContentsMeta
    }
    '^defaults$' {
      ContentsDefaults
    }
    '^vars$' {
      ContentsVars
    }
    '^tasks$' {
      ContentsTask
    }
    default {
      Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
      break
    }
  }
  Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()

}

