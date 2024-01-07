<#
.SYNOPSIS
Short description
.DESCRIPTION
Long description
.EXAMPLE
Example of how to use this cmdlet
.EXAMPLE
Another example of how to use this cmdlet
.INPUTS
Inputs to this cmdlet (if any)
.OUTPUTS
Output from this cmdlet (if any)
.NOTES
General notes
.COMPONENT
The component this cmdlet belongs to
.ROLE
The role this cmdlet belongs to
.FUNCTIONALITY
The functionality that best describes this cmdlet
#>
function Get-ChocolateyPackagesScriptBlock {
  [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
    SupportsShouldProcess = $false,
    PositionalBinding = $false,
    ConfirmImpact = 'Medium')]
  [Alias()]
  [OutputType([string])]
  Param (
    # Param1 help description
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string[]] $ChocolateyPackageNames
    ,
    [Parameter(Mandatory = $true,
      Position = 1,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string[]] $chocolateyPackageInfoSourcePath
    # $chocolateyPackageInfoSourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\ChocolateyPackageInfo.yml'
  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    [System.Text.StringBuilder]$sbAddedParameters = [System.Text.StringBuilder]::new()
    $addedParametersScriptblock = {
      param(
        [string[]]$addedParameters
      )
      if ($addedParameters) {
        foreach ($ap in $addedParameters) { [void]$sbAddedParameters.Append("/$ap ") }
        # [void]$sbAddedParameters.Append('"')
        $sbAddedParameters.ToString()
        [void]$sbAddedParameters.Clear()
      }
    }

    # ToDo: validate $chocolateyPackageInfoSourcePath is present and valid
    $chocolateyPackageInfos = ConvertFrom-Yaml $(Get-Content -Path $chocolateyPackageInfoSourcePath -Raw )

  }

  Process {}

  END {

    [void]$sb.Append(@'

# ChocolateyPackages
- name: Install the Chocolatey Packages
  hosts: all
  gather_facts: false
  tasks:
    - name: Install the Chocolatey Packages
      win_chocolatey:
        name: '{{ item.name }}'
        version: '{{ item.version }}'
        allow_prerelease: "{{ 'True' if (item.AllowPrerelease == 'true') else 'false'}}"
        state: "{{ 'absent' if (action_type == 'Uninstall') else 'present'}}"
        {% if item.AddedParameters is defined and item.AddedParameters|length %}
        'package_params: ' "{{ item.AddedParameters }}"
        {% endif %}
      failed_when: false # Setting this means if one package fails, the loop will continue. You can remove it if you don't want that behaviour.
      loop:
'@)


    for ($index = 0; $index -lt $ChocolateyPackageNames.count; $index++) {
      $packageName = $ChocolateyPackageNames[$index]
      $packageVersion = $chocolateyPackageInfos[$packageName].Version
      $allowPrerelease = $chocolateyPackageInfos[$packageName].AllowPrerelease
      $addedParameters = . $addedParametersScriptblock $chocolateyPackageInfos[$packageName].AddedParameters

      [void]$sb.Append("        - {name: $packageName, version: $packageVersion, AllowPrerelease: $allowPrerelease, AddedParameters: $addedParameters}")
      [void]$sb.Append("`n")

    }
    [void]$sb.Append(@"
      # when: "'$ansibleGroupName' in group_names "
  tags: [$ansiblegroupname, ChocolateyPackages]
"@)


    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $sb.ToString()
  }
}
