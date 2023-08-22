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

#   # add references to external assemblies. Ensure the assemblies referenced are compatable with the current default DotNet framework
# # reference the YamlDotNet.dll assembly found in the current directory
# $yamlDotNetAssemblyPath = join-path ".." "ATAP.Utilities.Ansible.dll"

# # Load the custom DLL
# Add-Type -Path $yamlDotNetAssemblyPath

  [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
  # The role defines roleComponent to be created
  $roleComponentNames = [System.Collections.ArrayList]($RoleInfo.Keys)

  $ChocolateyPaackageArgumentsInstance = New-Object ATAP.Utilities.Ansible.ChocolateyPackageArguments -ArgumentList 'AName'

# Now you have an instance of MyCustomClass created using the constructor
Write-Host "Instance created: $($ChocolateyPaackageArgumentsInstance.GetType().FullName)"
  for ($roleComponentIndex = 0; $roleComponentIndex -lt $roleComponentNames.Count; $roleComponentIndex++) {
    $roleComponentName = $roleComponentNames[$roleComponentIndex]
    switch -regex ($roleComponentName) {
      '^tasks$' {
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleComponentName ) -replace '\{2}', $roleName))
        # the task roleComponent defines plays and the orders to execute them
        $playInfos = [System.Collections.ArrayList]($RoleInfo[$roleComponentName])
        for ($playInfoIndex = 0; $playInfoIndex -lt $playInfos.Count; $playInfoIndex++) {
          $playInfo = $playInfos[$playInfoIndex]
          # Each play consists of one or more scriptblocks, and the parameters for each scriptblock
          for ($ansibleScriptblockNameIndex = 0; $ansibleScriptblockNameIndex -lt $ansibleScriptblockNames.Count; $ansibleScriptblockNameIndex++) {
            # execute the scriptblock, pass the list of arguments
            . Scriptblock$($playInfo.Kind) -Name $playInfo.Name -Args $playinfo.args -RoleName $rolename
            $roleSubdirectoryMainYamlPath = $(Join-Path $baseRoleDirectoryPath $roleComponentNames 'main.yml')
            Set-Content -Path $roleSubdirectoryMainYamlPath -Value $sb.ToString()
            [void]$sb.Clear()
          }
        }
      }
      '^vars$' {
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleComponentName ) -replace '\{2}', $roleName))
        # The vars RoleComponent are an araylist of strings in the form name:value
        # [void]$sb.AppendLine($($($template -replace '\{1}', $roleComponentName ) -replace '\{2}', $roleName))
        $roleSubdirectoryMainYamlPath = $(Join-Path $baseRoleDirectoryPath $roleComponentNames 'main.yml')
        Set-Content -Path $roleSubdirectoryMainYamlPath -Value $sb.ToString()
        [void]$sb.Clear()
      }
      '^meta$' {
        # The meta RoleComponent has a few simple parameters to act as replacements for the meta scriptblock
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
        . Scriptblock$($playInfo.Kind) -Name $playInfo.Name -Args $playinfo.args -RoleName $rolename
        $roleSubdirectoryMainYamlPath = $(Join-Path $baseRoleDirectoryPath $roleComponentNames 'main.yml')
        Set-Content -Path "$roleName\main.yml" -Value $sb.ToString()
        [void]$sb.Clear()
      }
      default {
        Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
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

