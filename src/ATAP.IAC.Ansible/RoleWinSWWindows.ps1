# The script that creates the WinSW Role
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
[System.Text.StringBuilder]$sbTemplates = [System.Text.StringBuilder]::new()
[System.Text.StringBuilder]$sbTasks = [System.Text.StringBuilder]::new()

$addedParametersScriptblock = { if ($addedParameters) {
    # [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    # [void]$sb.Append('Params: "')
    # foreach ($ap in $addedParameters) { [void]$sb.Append("/$ap ") }
    # [void]$sb.Append('"')
    # $sb.ToString()
  }
}

function ContentsMeta {
  [void]$sbMeta.Append(@'
author: William Hertzing for ATAP.org
description: Ansible role to install the WinSW software, which among other things can run a Java application as a service
attribution:
company: ATAP.org
role_name: WinSW
license: license (MIT)
min_ansible_version: 2.4
dependencies: [WinSW]
'@)
}

function ContentsDefaults {
  [void]$sbDefaults.Append(@"
# WinSW installation directory
WinSWLocalPath: "C:\\WinSW"
WinSWRemoteURL: "https://github.com/winsw/winsw/releases/download/{{ winsw_service_wrapper_version }}/WinSW.NET461.exe"
"@)
}

function ContentsVars {
  # Needed packages to setup agent
  # jenkins_agent_win_base_packages:
  # - jre8
  # - nssm
  [void]$sbVars.Append(@"
WinSWVersion: "v2.12.0"
"@)
}

function ContentsTemplates {
  # Needed packages to setup agent
  # jenkins_agent_win_base_packages:
  # - jre8
  # - nssm
  [void]$sbTemplates.Append(@'

  id: "{{ winsw_service_id | mandatory }}"
  name: "{{ winsw_service_name | mandatory }}"
  description: "{{ winsw_service_description | mandatory }}"
  stoptimeout: {{ winsw_service_stop_timeout | mandatory }}
  priority: "{{ winsw_service_priority | mandatory }}"
  onFailure:
    - action: {{ winsw_service_on_failure }}
  {% if winsw_service_log_mode != 'append' %}
  log:
    mode: "{{ winsw_service_log_mode | mandatory }}"
    logPath: "{{ winsw_service_logs_dir | mandatory }}"
    sizeThreshold: {{ winsw_service_log_size | mandatory }}
    keepFiles: {{ winsw_service_log_keep | mandatory }}
  {% if winsw_service_log_mode == 'roll-by-size-time' %}
    pattern: "{{ winsw_service_log_pattern | mandatory }}"
    autoRollAtTime: "{{ winsw_service_log_roll_at | mandatory }}"
  {% endif %}
  {% if winsw_service_log_stdout_disabled %}
    outfiledisabled: true
  {% endif %}
  {% if winsw_service_log_stderr_disabled %}
    errFileDisabled: true
  {% endif %}
  {% endif %}
  {% if winsw_service_logon_enabled %}
  serviceAccount:
    domain: "{{ winsw_service_logon_domain | mandatory }}"
    user: "{{ winsw_service_user | mandatory }}"
    password: "{{ winsw_service_logon_pass | mandatory }}"
    # WARNING: Does not work, requires manual intervention.
    allowservicelogon: true
  env:
  {% endif %}
  {% for key, val in winsw_service_environment.items() %}
    - { name: "{{ key }}", value: "{{ val }}" }
  {% endfor %}
  workingdirectory: "{{ winsw_service_work_dir | mandatory }}"
  executable: "{{ winsw_service_exe_path | mandatory }}"
  arguments: >
    {{ winsw_service_arguments | indent( width=2) }}
'@)
}

function ContentsTask {
  # ToDo grant Login and LoginAsAService rights to the user
  # ToDo: set a password expiry duration, anbd write a play/playbook to update the password for the Jenkins Agent Service Account User
  [void]$sbTasks.Append(@"

# ToDo: confirm that the jenkins controller is running and can be reached from the jenkins agent's host

- name: Install or Uninstall Jenkins Agent Service Account User
  ansible.windows.win_user:
    name: "{{ ServiceAccountName }}"
    fullname: "{{ ServiceAccountFullname }}"
    description: "{{ ServiceAccountDescription }}"
    password: "{{ ServiceAccountPasswordFromAnsibleVault }}"
    groups:
    - "WinSWs"
    password_never_expires: true
    account_disabled: false

- name: Create or Delete a home directory for the Jenkins Agent Service Account User
  ansible.windows.win_file:
    path: "{{ ServiceAccountUserHomeDirectory }}"
    state: directory

- name: Manage Jenkins Agent Service Account User Home Directory Permissions
  win_acl:
    path: "{{ ServiceAccountUserHomeDirectory }}"
    propagation: "InheritOnly"
    rights: "FullControl"
    type: "allow"
    user: "{{ ServiceAccountName }}"

- name: Create or Delete a Powershell (Core) subdirectory for the Jenkins Agent Service Account User
  ansible.windows.win_file:
    path: "{{ ServiceAccountUserHomeDirectory }}\\Powershell"
    state: directory

- name: Create or Delete a Powershell (Desktop) subdirectory for the Jenkins Agent Service Account User
  ansible.windows.win_file:
    path: "{{ ServiceAccountUserHomeDirectory }}\\WindowsPowershell"
    state: directory

- name: Install or Uninstall Jenkins Agent Service Account User's Powershell Core profile
  win_copy:
    src: "{{ ServiceAccountPowershellCoreProfileSource }}"
    dest: "{{ ServiceAccountUserHomeDirectory }}\\Powershell\\profile.ps1"

- name: Install or Uninstall Jenkins Agent Service Account User's Powershell Desktop profile
  win_copy:
    src: "{{ ServiceAccountPowershellDesktopProfileSource }}"
    dest: "{{ ServiceAccountUserHomeDirectory }}\\WindowsPowershell\\profile.ps1"

# ToDo: install WinSW

- name: Check if Agent Jar exists already
  win_stat:
    path: "{{ ServiceAccountUserHomeDirectory }}\\agent.jar"
  register: jenkins_AGENT_win_agent_jar

- name: Download Jenkins Agent Jar from Jenkins Server
  win_get_url:
    url: "{{ jenkins_slave_win_jenkins_url }}/jnlpJars/agent.jar"
    dest: "{{ ServiceAccountUserHomeDirectory }}\\agent.jar"
  when: not jenkins_slave_win_agent_jar.stat.exists

- name: Get Jenkins Slave's Secret
  uri:
    url: "{{ jenkins_slave_win_jenkins_url }}/scriptText"
    method: POST
    body: "script=println jenkins.model.Jenkins.instance.nodesObject.getNode('{{ ansible_hostname | lower }}')?.computer?.jnlpMac"
    user: "{{ jenkins_slave_win_jenkins_user }}"
    password: "{{ jenkins_slave_win_jenkins_password }}"
    force_basic_auth: true
    return_content: true
  changed_when: false
  register: jenkins_slave_win_agent_secret
  tags:
    - jenkins-secret
  delegate_to: localhost

- name: install or uninstall Jenkins Agent using chocolatey
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: "{{ JenkinsName }}"
    Version: "{{ JenkinsVersion }}"
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    $(. $addedParametersScriptblock)

"@)
}

# exclude these role subdirectores
$excludedSubDirectoriesPattern = '^handlers|files|library|module_utils|lookup_plugins|scripts$'
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
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sbDefaults.ToString()
    }
    '^vars$' {
      [void]$sbVars.AppendLine($introductoryStanza)
      ContentsVars
      Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sbVars.ToString()
    }
    '^templates$' {
      [void]$sbTemplates.AppendLine($introductoryStanza)
      ContentsTemplates
      Set-Content -Path "$roleSubdirectoryPath\service.yml" -Value $sbTemplates.ToString()
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

# name of JRE package should be a parameter
# version of JRE package should be a parameter
