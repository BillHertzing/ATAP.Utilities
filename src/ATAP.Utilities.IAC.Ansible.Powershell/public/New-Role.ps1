# The script that creates an Ansible Role
# dotsourced by an enclosing script
# using namespace ATAP.IAC.Ansible
# $assemblyFileName = "ATAP.IAC.Ansible.dll"
# $assemblyFilePath = join-path ".." $assemblyFileName
# Add-Type -Path $assemblyFilePath.FullName

function New-Role {
  param(
    # roleName help description
    [Parameter(Mandatory = $true,
      Position = 2,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string] $roleName
    # Template help description
    , [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $template
    # baseRoleDirectoryPath help description
    , [Parameter(Mandatory = $true,
      Position = 1,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string] $baseRoleDirectoryPath
    # RoleInfo help description
    , [Parameter(Mandatory = $true,
      Position = 3,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [hashtable] $RoleInfo
  )

  [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
  # The role defines roleComponent to be created
  $roleComponentNames = [System.Collections.ArrayList]($RoleInfo.Keys)

  for ($roleComponentIndex = 0; $roleComponentIndex -lt $roleComponentNames.Count; $roleComponentIndex++) {
    $roleComponentName = $roleComponentNames[$roleComponentIndex]
    switch -regex ($roleComponentName) {
      '^Name$' {
        break
      }
      '^AnsibleTask$' {
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleComponentName ) -replace '\{2}', "the Role $roleName"))
        # the task roleComponent defines plays and the orders to execute them
        $taskInfo = $RoleInfo[$roleComponentName]
        $taskName = $taskInfo['Name']
        $playInfos = $taskInfo['Items']
        $args = @{taskName = $taskName; taskInfo = $taskInfo; playInfos = $playInfos; tagnames = @(, $roleName); sb = $sb }
        &  RoleComponentTask @args

        # foreach ($play in $playInfos) {
        #   $ScriptBlockName = $play.Kind -replace 'AnsiblePlayBlock', 'Scriptblock'
        #   # execute the scriptblock, pass the list of arguments
        #   $args = @{name = $play.Name; items = $play.Items; tagnames =  @(,$roleName); sb = $sb }
        #   & $ScriptBlockName @args
        # }
        $roleComponentDirectory = $(Join-Path $baseRoleDirectoryPath $roleName 'tasks')
        $null = New-Item -ItemType Directory -Force $roleComponentDirectory
        $roleComponentMainYamlPath = Join-Path $roleComponentDirectory 'main.yml'
        Set-Content -Path $roleComponentMainYamlPath -Value $sb.ToString()
        [void]$sb.Clear()
      }
      '^vars$' {
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleComponentName ) -replace '\{2}', $roleName))
        # The vars RoleComponent are an araylist of strings in the form name:value
        # [void]$sb.AppendLine($($($template -replace '\{1}', $roleComponentName ) -replace '\{2}', $roleName))
        $roleSubdirectoryMainYamlPath = $(Join-Path $baseRoleDirectoryPath $roleName 'main.yml')
        Set-Content -Path $roleSubdirectoryMainYamlPath -Value $sb.ToString()
        [void]$sb.Clear()
      }
      '^AnsibleMeta$' {
        # The meta RoleComponent has a few simple parameters to act as replacements for the meta scriptblock
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleComponentName ) -replace '\{2}', $roleName))
        $metaInfo = $RoleInfo[$roleComponentName]
        $metaName = $metaInfo['Name']
        $args = @{roleName = $roleName; description = $metaInfo['description']; dependencies = $metaInfo['dependencies']; tagnames = @(, $roleName); sb = $sb }
        &  RoleComponentMeta @args
        $roleComponentDirectory = $(Join-Path $baseRoleDirectoryPath $roleName 'meta')
        $null = New-Item -ItemType Directory -Force $roleComponentDirectory
        $roleComponentMainYamlPath = Join-Path $roleComponentDirectory 'main.yml'
        Set-Content -Path $roleComponentMainYamlPath -Value $sb.ToString()
        [void]$sb.Clear()
      }
      default {
        Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleComponentName subDirectory"
        break
      }
    }

  }

  # exclude these role subdirectores
  # $excludedSubDirectoriesPattern = '^handlers|defaults|files|templates|library|module_utils|lookup_plugins|scripts$'
  # $subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
  # for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
  #   $roleSubdirectoryName = $subDirectoriesToBuild[$index]
  #   $roleSubdirectoryPath = $(Join-Path $baseRoleDirectoryPath $roleName)
  #   New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
  #   switch -regex ($roleSubdirectoryName) {
  #     '^tasks$' {
  #       [void]$sb.AppendLine($($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
  #       ContentsTask
  #       Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
  #       [void]$sb.Clear()
  #     }
  #     '^vars$' {
  #       [void]$sb.AppendLine($($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
  #       ContentsVars
  #       Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
  #       [void]$sb.Clear()
  #     }
  #     '^meta$' {
  #       [void]$sb.AppendLine($($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
  #       ContentsMeta
  #       Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
  #       [void]$sb.Clear()
  #     }
  #     default {
  #       Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
  #       break
  #     }
  #   }
  # }
}

