# The script that creates the Ruby Interpreter Role
function New-RoleRubyInterpreterWindows {
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

  # use a local $sb for each file type
  [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

  [System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()

  $addedParametersScriptblock = {
    param(
      [string[]]$addedParameters
    )
    if ($addedParameters) {
      [void]$sbAddedParameters.Append('Params: "')
      foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
      [void]$sbAddedParameters.Append('"')
      $sbAddedParameters.ToString()
      [void]$sbAddedParameters.Clear()
    }
  }
  function ContentsTask {
    [void]$sb.Append(@"

- name: Install or Uninstall Ruby using chocolatey
  win_dsc:
    resource_name: cChocoPackageInstaller
    Name: "{{ RubyName }}"
    Version: "{{ RubyVersion }}"
    Ensure: "{{ 'Absent' if (action_type == 'Uninstall') else 'Present'}}"
    $(. $addedParametersScriptblock)
  tags: [$roleName]
"@)
    # ToDo Fix AddedParameters for chocolatey installation
  }

  function ContentsVars {
    [void]$sb.Append(@'
RubyName: ruby
RubyVersion: 3.1.3.1
RubyAllow_prerelease: false
'@)
    # ToDo Fix AddedParameters for chocolatey installation
  }

  function ContentsMeta {
    [void]$sb.Append(@'
dependencies:
  # - TBD
'@)
  }

  # exclude these role subdirectores
  $excludedSubDirectoriesPattern = '^handlers|defaults|files|templates|library|module_utils|lookup_plugins|scripts$'
  $subDirectoriesToBuild = $roleSubdirectoryNames | Where-Object { $_ -notmatch $excludedSubDirectoriesPattern }  # minus the excluded ones
  for ($index = 0; $index -lt $subDirectoriesToBuild.count; $index++) {
    $roleSubdirectoryName = $subDirectoriesToBuild[$index]
    $roleSubdirectoryPath = $(Join-Path $roleDirectoryPath $roleSubdirectoryName)
    New-Item -ItemType Directory -Path $roleSubdirectoryPath -ErrorAction SilentlyContinue >$null
    switch -regex ($roleSubdirectoryName) {
      '^tasks$' {
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
        ContentsTask
        Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
        [void]$sb.Clear()
      }
      '^vars$' {
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
        ContentsVars
        Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
        [void]$sb.Clear()
      }
      '^meta$' {
        [void]$sb.AppendLine($($($template -replace '\{1}', $roleSubdirectoryName ) -replace '\{2}', $roleName))
        ContentsMeta
        Set-Content -Path "$roleSubdirectoryPath\main.yml" -Value $sb.ToString()
        [void]$sb.Clear()
      }
      default {
        Write-PSFMessage -Level Error -Message " role $roleName has no template to create any files in the $roleSubdirectoryName subDirectory"
        break
      }
    }
  }
}
