<#
.SYNOPSIS
Registers the sixteen flat orchestration setting-name constants.
.DESCRIPTION
Requires an initialized Hashtable. Checks every existing orchestration mapping
before adding missing constants, preserves unrelated keys and is idempotent.
Defines names only: no settings, defaults, host paths or measured limits.
.OUTPUTS
None.
.EXAMPLE
Set-OrchestrationConfigRootKeys -WhatIf
.NOTES
Source candidate for Task 17.19.a. Does not establish deployed configuration.
.LINK
Set-GlobalConfigRootKeys
#>
function Set-OrchestrationConfigRootKeys {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
  [OutputType([void])]
  param()

  begin {
    $fn = 'Set-OrchestrationConfigRootKeys'
    $mn = 'ATAP.Utilities.ConfigRootKeys.PowerShell'
    $keyTable = Get-Variable -Name configRootKeys -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    if ($keyTable -isnot [hashtable]) {
      throw '$global:configRootKeys is not an initialized Hashtable. Run Set-GlobalConfigRootKeys first.'
    }
    $mappings = [ordered]@{
      OrchestrationMaxRequestBytesConfigRootKey = 'OrchestrationMaxRequestBytes'
      OrchestrationMaxBatchRequestsConfigRootKey = 'OrchestrationMaxBatchRequests'
      OrchestrationMaxBatchBytesConfigRootKey = 'OrchestrationMaxBatchBytes'
      OrchestrationMaxDrainRequestsConfigRootKey = 'OrchestrationMaxDrainRequests'
      OrchestrationMaxDrainBatchesConfigRootKey = 'OrchestrationMaxDrainBatches'
      OrchestrationMaxDrainMillisecondsConfigRootKey = 'OrchestrationMaxDrainMilliseconds'
      OrchestrationMaxRetryAttemptsConfigRootKey = 'OrchestrationMaxRetryAttempts'
      OrchestrationRetryBudgetMillisecondsConfigRootKey = 'OrchestrationRetryBudgetMilliseconds'
      OrchestrationClosedSprintRetentionDaysConfigRootKey = 'OrchestrationClosedSprintRetentionDays'
      OrchestrationMigrationRetentionDaysConfigRootKey = 'OrchestrationMigrationRetentionDays'
      OrchestrationStateRootPathConfigRootKey = 'OrchestrationStateRootPath'
      OrchestrationCustodyRecordPathConfigRootKey = 'OrchestrationCustodyRecordPath'
      OrchestrationProtectedBackupRootPathConfigRootKey = 'OrchestrationProtectedBackupRootPath'
      OrchestrationBackupPolicyReferenceConfigRootKey = 'OrchestrationBackupPolicyReference'
      OrchestrationResourceRegistryPathConfigRootKey = 'OrchestrationResourceRegistryPath'
      OrchestrationCompatibilityMatrixPathConfigRootKey = 'OrchestrationCompatibilityMatrixPath'
    }
  }

  process {
    try {
      # Inspect logical string-key aliases independently of the Hashtable comparer.
      # No writes until every mapping has one exact canonical spelling or is absent.
      foreach ($entry in $mappings.GetEnumerator()) {
        $aliases = @($keyTable.Keys | Where-Object {
          $_ -is [string] -and [string]::Equals($_, $entry.Key, [StringComparison]::OrdinalIgnoreCase)
        })
        if ($aliases.Count -gt 1) {
          throw "Ambiguous orchestration key spelling: $($entry.Key)"
        }
        if ($aliases.Count -eq 1) {
          $existingValue = $keyTable[$aliases[0]]
          if ($existingValue -isnot [string] -or $existingValue -cne $entry.Value) {
            throw "Conflicting orchestration key mapping: $($entry.Key)"
          }
          if (-not [string]::Equals($aliases[0], $entry.Key, [StringComparison]::Ordinal)) {
            throw "Ambiguous orchestration key spelling: $($entry.Key)"
          }
        } elseif ($keyTable.ContainsKey($entry.Key)) {
          # Refuse a native-comparer collision with an unrecognized nonstring key.
          throw "Ambiguous orchestration key spelling: $($entry.Key)"
        }
      }
      if ($PSCmdlet.ShouldProcess('$global:configRootKeys', 'Register sixteen orchestration name constants')) {
        foreach ($entry in $mappings.GetEnumerator()) {
          if (-not $keyTable.ContainsKey($entry.Key)) {
            $keyTable.Add($entry.Key, $entry.Value)
          }
        }
        if (Get-Module -Name PSFramework) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Orchestration name constants registered.'
        }
      }
    } catch {
      if (Get-Module -Name PSFramework) {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message 'Orchestration name registration refused or failed.'
      }
      throw
    }
  }

  end {
    # No settings resolution, initialization or deployment.
  }
}
