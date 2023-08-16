# The script that creates the Java Interpreter Role
function New-RoleJavaInterpreterWindows {
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
      [void]$sbAddedParameters.Append('"')
      foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
      [void]$sbAddedParameters.Append('"')
      $sbAddedParameters.ToString()
      [void]$sbAddedParameters.Clear()
    }
  }

  function ContentsTask {
    [void]$sb.Append(@"
	- name: install the chocolatey packages
	  win_chocolatey:
		name: '{{ item.name }}'
		# version: '{{ item.version }}'
		allow_prerelease: "{{ 'true' if (item.allowprerelease == 'true') else 'false'}}"
		state: "{{ 'absent' if (action_type == 'uninstall') else 'present'}}"
		# {% if item.addedparameters is defined and item.addedparameters|length %}
		# 'package_params: ' "{{ item.addedparameters }}"
		# {% endif %}
	  failed_when: false # setting this means if one package fails, the loop will continue. you can remove it if you don't want that behaviour.
	  loop:
		- {name: temurin17jre, version: 17.0.6.1000, allowprerelease: false, addedparameters: "InstallDir:'C:\Program Files\PythonInterpreters\Python3.10.11" }
  tags: [$roleName]
  ignore_errors: yes
  # $addedParameters = . $addedParametersScriptblock @('ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome', 'ch') # {{ ProgramFiles }}{{ JavaInstallDirRelativeSubdirectory }}
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
    $introductoryStanza = $($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName)
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
}
