# The script that creates the ProGetPackageRepositoryProvider Role
function New-RoleProGetPackageRepositoryProviderWindows {
  param(
    # Template help description
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $template
    # roleDirectoryPath help description
    , [Parameter(Mandatory = $true,
      Position = 1,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string] $roleDirectoryPath
    # roleName help description
    , [Parameter(Mandatory = $true,
      Position = 2,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string] $roleName
    # roleName help description
    , [Parameter(Mandatory = $true,
      Position = 3,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string[]] $roleSubdirectoryNames
    # SwCfgInformation help description
    , [Parameter(Mandatory = $true,
      Position = 4,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [hashtable] $swCfgInformation
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
  description: Ansible role to setup a ProGetPackageRepositoryProvider on Windows installed as a service via Chocolatey
  attribution:
  company: ATAP.org
  role_name: ProGetPackageRepositoryProviderWindows
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
    # ToDo: set a password expiry duration, and write a play/playbook to update the password
    #    ToDo: for the ProGetPackageRepositoryProvider Service Account
    # ToDO: support for pre-release version of ChocolateyPackage
    # ToDo: support for specific log file for the chocolatey package installation process
    # ToDo: installation arguments for the controller
    #  /InstallDir
    #  /Port
    #  /Service_Username
    #  /Service_Password
    [void]$sb.Append(@"

- name: Install the ProGetPackageRepositoryProvider Service Account User, it's user directory, ACL permissions on the user directory, and Powershell Core and Desktop profiles
  block:
  - name: Call the Create-ServiceAccount.ps1 script found in the ATAP.Utilities.Buildtooling.Powershell module
    ansible.windows.win_powershell:
      executable: pwsh.exe
      script: |
        # Import-module  ATAP.Utilities.BuildTooling.Powershell
        . "D:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Create-ServiceAccount.ps1"
        Create-ServiceAccount -ServiceAccount "{{ $($global:configRootKeys['ProGetPackageRepositoryProviderServiceAccountConfigRootKey']) }}" -ServiceAccountPasswordKey "{{ $($global:configRootKeys['ProGetPackageRepositoryProviderServiceAccountPasswordKeyConfigRootKey']) }}" -ServiceAccountFullname "{{ $($global:configRootKeys['ProGetPackageRepositoryProviderServiceAccountFullnameConfigRootKey']) }}" -ServiceAccountDescription "'{{ $($global:configRootKeys['ProGetPackageRepositoryProviderServiceAccountDescriptionConfigRootKey']) }}'" -ServiceAccountUserHomeDirectory "{{ $($global:configRootKeys['ProGetPackageRepositoryProviderServiceAccountUserHomeDirectoryConfigRootKey']) }}" -ServiceAccountPowershellDesktopProfileSourcePath "{{ $($global:configRootKeys['ProGetPackageRepositoryProviderServiceAccountPowershellDesktopProfileSourcePathConfigRootKey']) }}" -ServiceAccountPowershellCoreProfileSourcePath "{{ $($global:configRootKeys['ProGetPackageRepositoryProviderServiceAccountPowershellCoreProfileSourcePathConfigRootKey']) }}" -State "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    register: CreateServiceAccountResultOutput

  - name: Parse the returned JSON string into a JSON object
    set_fact:
      CreateServiceAccountResultObject: "{{ CreateServiceAccountResultOutput.result | from_yaml }}"

  - name: Debug output
    debug:
      var: CreateServiceAccountResultObject

# - name: Manage ProGetPackageRepositoryProvider Service Account User Home Directory Permissions
#   win_acl:
#     path: "{{ ServiceAccountUserHomeDirectory }}"
#     propagation: "InheritOnly"
#     rights: "FullControl"
#     type: "allow"
#     user: "{{ ServiceAccountName }}"


  - name: Install or Uninstall ProGetPackageRepositoryProvider using chocolatey
    win_dsc:
      resource_name: cChocoPackageInstaller
      Name: "{{ item.name }}"
      Version: "{{ item.version }}"
      Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
      Params: "{{ item.AddedParameters if item.AddedParameters else omit }}"
    loop:

    # The following is a task (not role) definition created by Gemini on 05/19/2025
# - ProGetServerWindows:
- name: Stop ProGet Service
  win_service:
    name: ProGet
    state: stopped

- name: Deploy ProGet Configuration
  win_template:
    src: "ProGetConfig.config.j2"
    dest: "C:\\ProgramData\\Inedo\\ProGet\\ProGetConfig.config"
  notify: Start ProGet Service

- name: Deploy ProGet Web Application Configuration (if needed)
  win_template:
    src: "web.config.j2"
    dest: "C:\\Program Files (x86)\\Inedo\\ProGet\\ProGetWebApp\\web.config"
  notify: Restart IIS

- name: Deploy ProGet Service Configuration (if needed)
  win_template:
    src: "ProGet.Service.exe.config.j2"
    dest: "C:\\Program Files (x86)\\Inedo\\ProGet\\ProGet.Service.exe.config"
  notify: Restart ProGet Service

- name: Start ProGet Service
  win_service:
    name: ProGet
    state: started
  listen: "Start ProGet Service"


"@)

    $packageName = 'proget'
    $packageVersion = '24.0.35'
    $allowPrerelease = $false
    # ToDo: lookup the password from a vault using the passwordKey
    $ServiceUsernameParam = "Service_Username=""{{ $($global:configRootKeys['ProGetPackageRepositoryProviderServiceAccountConfigRootKey']) }}"""
    $ServicePasswordParam = "Service_Password=""{{ $($global:configRootKeys['ProGetPackageRepositoryProviderServiceAccountPasswordKeyConfigRootKey']) }}"""
    # ToD: remnants of prior role this is copied from, not accurate yet
    $addedParameters = . $addedParametersScriptblock @('PORT=8081', 'INSTALLDIR=''''C:/Program Files/ProGetPackageRepositoryProvider2''''', 'JENKINS_ROOT=''''D:/Dropbox/ProGetPackageRepositoryProviderRoot2''''', $ServiceUsernameParam, $ServicePasswordParam)

    [void]$sb.AppendLine("      - {name: $packageName, version: $packageVersion, AllowPrerelease: $allowPrerelease, AddedParameters: $addedParameters}")
    [void]$sb.Append(@"

  # Note that the TBD environment variable is set via the ProGetPackageRepositoryProvider Service Account's user profile
  # If the host is the Active ProGetPackageRepositoryProvider, set the appropriate environment variables
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
    $introductoryStanza = $($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName)
    [void]$sb.Clear()
    [void]$sb.AppendLine($introductoryStanza)
    switch -regex ($roleSubdirectoryName) {
      '^meta$' {
        ContentsMeta
        [void]$sb.Clear()
      }
      '^vars$' {
        ContentsVars
        [void]$sb.Clear()
      }
      '^tasks$' {
        ContentsTask
        [void]$sb.Clear()
      }
      default {
        Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
        break
      }
    }
    Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()

  }

}
