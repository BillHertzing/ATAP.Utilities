# The script that creates an Ansible Role
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
    # ansibleStructure help description
    , [Parameter(Mandatory = $true,
      Position = 3,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [hashtable] $ansibleStructure
  )

  # The role defines roleComponent to be created
  $roleComponentNames = [System.Collections.ArrayList]($($($($ansibleStructure.SwCfgInfos).AnsibleRoleInfos)[$roleName]).Keys)
  for ($roleComponentIndex = 0; $roleComponentIndex -lt $roleComponentNames.Count; $roleComponentIndex++) {
    $roleComponentName = $roleComponentNames[$roleComponentIndex]
    $ansibleRoleInfo = $($($($ansibleStructure.SwCfgInfos).AnsibleRoleInfos)[$roleName])
    switch -regex ($roleComponentName) {
      '^tasks$' {
        # the task roleComponent defines plays and the orders to execute them
        $playNames = [System.Collections.ArrayList]($($ansibleRoleInfo[$roleComponentName]).Keys)
        for ($playNameIndex = 0; $playNameIndex -lt $playNames.Count; $playNameIndex++) {
          $playName = $playNames[$playNameIndex]
          # Each play consists of one or more scriptblocks, and the parameters for each scriptblock
          $ansiblePlayInfo = $($($($($ansibleStructure.SwCfgInfos).AnsibleRoleInfos)[$roleName]))[$playName]
          $ansibleScriptblockNames = [System.Collections.ArrayList]($ansiblePlayInfo.Keys)
          for ($ansibleScriptblockNameIndex = 0; $ansibleScriptblockNameIndex -lt $ansibleScriptblockNames.Count; $ansibleScriptblockNameIndex++) {
            $ansibleScriptblockName = $ansibleScriptblockNames[$ansibleScriptblockNameIndex]
            # execute the scriptblock
            . Scriptblock$($scriptblocksKey) $rolename

            [void]$sb.AppendLine($($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
            ContentsTask $ansibleRoleInfo['task']
            $roleSubdirectoryPath = $(Join-Path $baseRoleDirectoryPath $roleComponentNames 'main.yml')
            Set-Content -Path $roleSubdirectoryPath -Value $sb.ToString()
            [void]$sb.Clear()
          }
        }
      }
      '^vars$' {
        # The vars RoleComponent are an araylist of strings in the form name:value
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
        ContentsVars $ansibleRoleInfo['vars']
        Set-Content -Path "$roleName\main.yml" -Value $sb.ToString()
        [void]$sb.Clear()
      }
      '^meta$' {
        # The meta RoleComponent has a few simple parameters to act as replacements for the meta scriptblock
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
        ContentsMeta
        Set-Content -Path "$roleName\main.yml" -Value $sb.ToString()
        [void]$sb.Clear()
      }
      default {
        Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
        break
      }
    }

  }

  # If the role includes chocolatey packages

  # Import the scriptblock file for the role name
  . ./Role$($roleName)Scriptblocks.ps1


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
