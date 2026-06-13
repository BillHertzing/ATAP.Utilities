function Remove-SprintDatabases {
  <#
  .SYNOPSIS
    Drops sprint databases inside existing per-developer SQL Server instances.
  .DESCRIPTION
    Drops the sprint databases from the permanent per-developer SQL Server named
    instances used by the sprint lifecycle:

      - Dev<developer>
      - Exp<developer>

    The cmdlet does not create, install, uninstall, or delete SQL Server
    instances. It first verifies that every requested instance already exists
    (using the Windows service name MSSQL$<instance>), then drops each requested
    database using dbatools Remove-DbaDatabase.

    If any requested instance is missing, the cmdlet fails before dropping any
    database and reports onboarding remediation text so the developer knows what
    to do.

    -WhatIf and -DryRun are true no-op paths: they still perform the instance
    preflight, but they do not call Remove-DbaDatabase or execute any DROP.
    $WhatIfPreference propagates through the ShouldProcess gate so the inner
    Remove-DbaDatabase call is never reached when WhatIf is active.
  .PARAMETER DeveloperNames
    Developer names used to derive Dev<developer> and Exp<developer> instance
    names. Defaults to Sprint.DeveloperNames from global settings when
    available, otherwise $env:USERNAME.
  .PARAMETER InstanceNames
    Explicit SQL Server named-instance names to target. When supplied, overrides
    DeveloperNames-derived instance names.
  .PARAMETER Databases
    Database names to drop on every instance. Defaults to ATAPUtilities and
    AceCommander.
  .PARAMETER DatabaseHost
    SQL Server host address. Defaults to localhost.
  .PARAMETER DryRun
    Performs preflight only and returns the drop plan without calling
    Remove-DbaDatabase. No databases are dropped.
  .PARAMETER Force
    Bypasses confirmation prompts for non-interactive automation. Does not
    override -WhatIf.
  .OUTPUTS
    PSCustomObject[] with one row per instance/database pair.
    Fields: instanceName, database, environment, instanceReady, dropped, dryRun, skipped, error.
  .EXAMPLE
    Remove-SprintDatabases -Confirm:$false
  .EXAMPLE
    Remove-SprintDatabases -DryRun
  .EXAMPLE
    Remove-SprintDatabases -WhatIf
  .LINK
    Reset-SprintDatabases
  .LINK
    Remove-DeveloperSqlServerInstances
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param(
    [Parameter(Mandatory = $false)]
    [string[]]$DeveloperNames,

    [Parameter(Mandatory = $false)]
    [string[]]$InstanceNames,

    [Parameter(Mandatory = $false)]
    [string[]]$Databases,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseHost,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"

    if ($Force) {
      $ConfirmPreference = 'None'
    }

    if ([string]::IsNullOrWhiteSpace($DatabaseHost)) {
      $DatabaseHost = 'localhost'
    }

    if (-not $PSBoundParameters.ContainsKey('Databases') -or $null -eq $Databases -or $Databases.Count -eq 0) {
      $Databases = @('ATAPUtilities', 'AceCommander')
    }
    $Databases = @($Databases | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($Databases.Count -eq 0) {
      throw 'At least one database name is required.'
    }

    if (-not $PSBoundParameters.ContainsKey('InstanceNames') -or $null -eq $InstanceNames -or $InstanceNames.Count -eq 0) {
      if (-not $PSBoundParameters.ContainsKey('DeveloperNames') -or $null -eq $DeveloperNames -or $DeveloperNames.Count -eq 0) {
        $settingsKey = if ($global:configRootKeys -and $global:configRootKeys['SprintDeveloperNamesConfigRootKey']) {
          $global:configRootKeys['SprintDeveloperNamesConfigRootKey']
        } else {
          'Sprint.DeveloperNames'
        }

        if (Get-Command -Name 'Get-PVal' -ErrorAction SilentlyContinue) {
          $DeveloperNames = Get-PVal `
            -ParameterName 'DeveloperNames' `
            -originalPSBoundParameters $PSBoundParameters `
            -dottedPath $settingsKey `
            -DefaultValue @($env:USERNAME) `
            -AllowMissing
        }

        if (-not $DeveloperNames) {
          $DeveloperNames = @($env:USERNAME)
        }
      }

      $DeveloperNames = @($DeveloperNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
      if ($DeveloperNames.Count -eq 0) {
        throw 'At least one developer name is required to derive sprint SQL Server instance names.'
      }

      $resolvedInstanceNames = [System.Collections.Generic.List[string]]::new()
      foreach ($developer in $DeveloperNames) {
        $resolvedInstanceNames.Add("Dev$developer")
        $resolvedInstanceNames.Add("Exp$developer")
      }
      $InstanceNames = $resolvedInstanceNames.ToArray()
    }

    $InstanceNames = @($InstanceNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($InstanceNames.Count -eq 0) {
      throw 'At least one SQL Server instance name is required.'
    }

    # Only require dbatools when we will actually perform drops
    $isNoOp = [bool]($DryRun -or $WhatIfPreference)
    if (-not $isNoOp) {
      if (-not (Get-Command -Name 'Remove-DbaDatabase' -ErrorAction SilentlyContinue)) {
        throw 'dbatools is required for Remove-SprintDatabases (Remove-DbaDatabase not found). Install it: Install-Module dbatools -Force'
      }
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Instances: $($InstanceNames -join ', ') | Databases: $($Databases -join ', ') | Host: $DatabaseHost | DryRun: $DryRun"
  }

  process {
    $results = [System.Collections.Generic.List[object]]::new()
    $missingInstances = [System.Collections.Generic.List[string]]::new()

    foreach ($instanceName in $InstanceNames) {
      $serviceName = "MSSQL`$$instanceName"
      $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
      if ($null -eq $existingService) {
        $missingInstances.Add("$instanceName (service $serviceName)")
      }
    }

    if ($missingInstances.Count -gt 0) {
      $message = "Required SQL Server instance(s) not found: $($missingInstances -join ', '). " +
      'Run the developer onboarding SQL Server instance setup for this workstation, then rerun Remove-SprintDatabases. ' +
      'This cmdlet only drops databases; it never creates or removes SQL Server instances.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $message
      throw $message
    }

    foreach ($instanceName in $InstanceNames) {
      $environment = if ($instanceName.StartsWith('Dev')) { 'Development' }
      elseif ($instanceName.StartsWith('Exp')) { 'Experimental' }
      else { $instanceName }

      $sqlInstance = if ([string]::IsNullOrWhiteSpace($DatabaseHost) -or $DatabaseHost -eq 'localhost') {
        "localhost\$instanceName"
      } else {
        "$DatabaseHost\$instanceName"
      }

      foreach ($db in $Databases) {
        $target = "$sqlInstance\$db"

        $entry = [ordered]@{
          instanceName  = $instanceName
          database      = $db
          environment   = $environment
          instanceReady = $true
          dropped       = $false
          dryRun        = [bool]$DryRun
          skipped       = $false
          error         = $null
        }

        if ($DryRun) {
          $entry.skipped = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
            -Message "DryRun: would drop database '$db' on instance '$instanceName'."
          $results.Add([PSCustomObject]$entry)
          continue
        }

        # $WhatIfPreference propagates through ShouldProcess: when WhatIf is active,
        # ShouldProcess returns $false and Remove-DbaDatabase is never called.
        if (-not $PSCmdlet.ShouldProcess($target, "Drop sprint database '$db' from instance '$instanceName'")) {
          $entry.skipped = $true
          $results.Add([PSCustomObject]$entry)
          continue
        }

        try {
          $dbObject = Get-DbaDatabase -SqlInstance $sqlInstance -Database $db -ErrorAction SilentlyContinue
          if ($null -eq $dbObject) {
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Database '$db' not found on instance '$instanceName' — skipping (already dropped?)."
            $entry.skipped = $true
          } else {
            Remove-DbaDatabase -SqlInstance $sqlInstance -Database $db -Confirm:$false
            $entry.dropped = $true
            Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Important `
              -Message "Database dropped: instance=$instanceName db=$db"
          }
        } catch {
          $entry.error = "Remove-DbaDatabase failed for instance='$instanceName' db='$db'. Exception: $($_.Exception.Message)"
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $entry.error
        }

        $results.Add([PSCustomObject]$entry)
      }
    }

    return $results.ToArray()
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
  }
}
