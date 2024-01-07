
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
function New-PlaybooksTop {
  [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
    SupportsShouldProcess = $true,
    PositionalBinding = $false,
    ConfirmImpact = 'Medium')]
  [Alias()]
  [OutputType([Object])]
  Param (
    # Template help description
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $Template
    , # Path help description
    [Parameter(Mandatory = $true,
      Position = 1,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $Path
    , # InventoryStructure help description
    [Parameter(Mandatory = $true,
      Position = 2,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $InventoryStructure
    , # ImportDirectory help description
    [Parameter(Mandatory = $false,
      Position = 3,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    [string] $ImportDirectory
    , # AnsibleGroupName help description
    [Parameter(ParameterSetName = 'AnsibleGroupNames',
      Mandatory = $false,
      Position = 4,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $AnsibleGroupName
    , # hostName help description

    [Parameter(ParameterSetName = 'HostNames',
      Mandatory = $false,
      Position = 4,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNull()]
    [ValidateNotNullOrEmpty()]
    $hostName
  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    # script variables used in all scriptblocks
    $hostNames = $ansibleStructure.HostNames
    $ansibleGroupNames = $ansibleStructure.AnsibleGroupNames


    function MainFunction {

      function Contents {
        [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
        switch ($PSCmdlet.ParameterSetName) {
          AnsibleGroupNames {
            [void]$sb.Append(@'
- name: Top Playbook that imports all AnsibleGroupNames playbooks
  hosts: all
  gather_facts: false
  tasks:
    - name: Print action_type variable
      debug:
      var: action_type
# Include the playbook for every group

'@)
            for ($ansibleGroupNameIndex = 0; $ansibleGroupNameIndex -lt $ansibleGroupNames.count; $ansibleGroupNameIndex++) {
              $ansibleGroupName = $ansibleGroupNames[$ansibleGroupNameIndex]
              # if ($ansibleGroupName -ne 'WindowsHosts' ) { continue } # skip things for development

              [void]$sb.Append(@"
- import_playbook: "$importDirectory/$($ansibleGroupName)Playbook.yml"

"@)
            }
          }
          HostNames {
            [void]$sb.Append(@'
- name: Top Playbook that imports all HostNames playbooks
  hosts: all
  gather_facts: false
  tasks:
    - name: Print action_type variable
    debug:
    var: action_type
# Include the playbook for every host

'@)
            for ($hostNameIndex = 0; $hostNameIndex -lt $hostNames.count; $hostNameIndex++) {
              $hostName = $hostNames[$hostNameIndex]
              # if ($hostName -ne 'WindowsHosts' ) { continue } # skip things for development

              [void]$sb.Append(@"
- import_playbook: "$importDirectory/$($hostName)Playbook.yml"

"@)
            }
          }

          default {
            $message = "ParameterSetName = $($PSCmdlet.ParameterSetName)  has not been implemented yet"
            Write-PSFMessage -Level Error -Message $message -Tag '%FunctionName%'
            # toDo catch the errors, add to 'Problems'
            Throw $message
          }
        }
        [void]$sb.Append("`n")
        $sb.ToString()
      }
      $template += $(Contents)
      Set-Content -Path $Path -Value $template
    }
  }

  PROCESS {
    MainFunction
  }

  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }

}

