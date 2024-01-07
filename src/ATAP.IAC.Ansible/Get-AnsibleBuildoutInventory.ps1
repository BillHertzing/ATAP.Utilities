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
function Get-AnsibleBuildoutInventory {
  [CmdletBinding(DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern',
    SupportsShouldProcess = $false,
    PositionalBinding = $false,
    ConfirmImpact = 'Medium')]
  [Alias()]
  [OutputType([Object])]
  Param (
    # Param1 help description
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false)
    ]
    [ValidateNotNullOrEmpty()]
    #[ValidateCount(0,5)]
    #[ValidateSet("sun", "moon", "earth")]
    [Alias('AI')]
    $ansibleInventory
  )

  BEGIN {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.IAC.Ansible\Get-ChocolateyPackagesScriptBlock.ps1'
    Function MainProcess {
      $buildoutInventory = @{}

      [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

      $BuildoutInventoryPreambleScriptBlock = {
        [void]$sb.Append(@'
---
all:

'@)
      }

      $BuildoutInventoryPerHostScriptBlock = {
        [void]$sb.Append(@"
  $hostname :

"@)

        # Per host SW configuration groups
      }


      $HostNamesKeys = $ansibleInventory.HostNames
      for ($HostNamesIndex = 0; $HostNamesIndex -lt $HostNamesKeys.Count; $HostNamesIndex++) {
        $HostNamesKey = $HostNamesKeys[$HostNamesIndex]
        # iterate all of the SwCfg members
        for ($SwCfgIndex = 0; $SwCfgIndex -lt $ansibleInventory.SwCfg.Count; $SwCfgIndex++) {
          $SWConfigurationGroupsKey = $ansibleInventory.SwCfg.$SwCfgIndex
          # if the hosts section has a named SWConfigurationGroup,
          # Gather the SWConfigurationGroups and their value from the Hosts section #TBD
        }
        # iterate all of the AnsibleGroups members
        for ($AnsibleGroupsIndex = 0; $AnsibleGroupsIndex -lt $ansibleInventory.AnsibleGroups.Count; $AnsibleGroupsIndex++) {
          $AnsibleGroupsKey = $ansibleInventory.AnsibleGroups.$AnsibleGroupsIndex
          # if the hosts section has an AnsibleGroupNames section and the $AnsibleGroupsKey is present in that section
          if ($ansibleInventory.HostNames.$HostNamesKey.AnsibleGroupNames -contains $AnsibleGroupsKey) {
            # Gather the SWConfigurationGroups and their value from the AnsibleGroup section
            # ToDo: Perhpas validate the name in the hosts list matches an entry in the ansblegroups?
            for ($SwCfgIndex = 0; $SwCfgIndex -lt $ansibleInventory.AnsibleGroupNames.Count; $SwCfgIndex++) {
              $SWConfigurationGroupsKey = $ansibleInventory.AnsibleGroupNames.$SwCfgIndex
            }
          }
        }

        $ansibleInventoryHostNamesKeys = [System.Collections.ArrayList]($ansibleInventory.HostNames.$HostNamesKey.Keys)
        for ($ansibleInventoryHostNamesIndex = 0; $ansibleInventoryHostNamesIndex -lt $ansibleInventoryHostNamesKeys.Count; $ansibleInventoryHostNamesIndex++) {
          $SWConfigurationsKey = $ansibleInventoryHostNamesKeys[$ansibleInventoryHostNamesIndex]
          switch -regex ($SWConfigurationsKey) {
            'Settings|AnsibleGroupNames' {}
            default {
              #$ansibleInventoryHostNamesSWConfigurationNamesKey = $ansibleInventory.HostNames.$HostNamesKey.$SWConfigurationsKey
              if ($swCfg -notcontains $SWConfigurationsKey) { $swCfg += $SWConfigurationsKey }

            }

          }
        }
      }


      $hostNameKeys = [System.Collections.ArrayList]($ansibleInventory.HostNames.Keys)
      $ansibleGroupNameKeys = [System.Collections.ArrayList]($ansibleInventory.AnsibleGroupNames.Keys)

      for ($i = 0; $i -lt $hostNameKeys.Count; $i++) {
        $hostName = $hostNameKeys[$i]
        $buildoutInventory[$hostName] = @{}
        for ($j = 0; $j -lt $hostSWGroups.Count; $j++) {
          if ($($ansibleInventory.HostNames[$hostName]).containskey($hostSWGroups[$j])) {
            $($buildoutInventory[$hostName])[$hostSWGroups[$j]] = $($($ansibleInventory.HostNames[$hostName])[$hostSWGroups[$j]]).Clone()
          }
        }
        $hostAnsibleGroupNames = [System.Collections.ArrayList]($($ansibleInventory.HostNames[$hostName]).AnsibleGroupNames)
        for ($j = 0; $j -lt $hostAnsibleGroupNames.Count; $j++) {
          $buildoutInventory_hostNameKeys = [System.Collections.ArrayList]($($buildoutInventory[$hostName]).keys)
          if (-not $buildoutInventory_hostNameKeys.contains($hostAnsibleGroupNames[$j]) ) {
            # add new
            $($buildoutInventory[$hostName])[$hostAnsibleGroupNames[$j]] = $ansibleInventory.AnsibleGroupNames[$hostAnsibleGroupNames[$j]].Clone()
          }
          else {
            # add to existing
          }

        }
      }
      return $buildoutInventory
    }
  }

  PROCESS {
    MainProcess
  }

  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
}
