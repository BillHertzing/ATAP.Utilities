function Test-ATAPJavaRuntimeParity {
  <#
  .SYNOPSIS
  Tests Java runtime parity inventory against the ratified Task 15.182.J00 contract.

  .DESCRIPTION
  Evaluates secret-free host inventory objects and reports every contract violation.

  .PARAMETER Inventory
  Host inventory objects emitted by the Task 15.182 Java parity inventory collector.

  .OUTPUTS
  PSCustomObject containing IsCompliant and Drift.

  .EXAMPLE
  Test-ATAPJavaRuntimeParity -Inventory $inventory.Hosts

  .NOTES
  Task 15.182.j.

  .LINK
  InformationForTheFuture/Sprint0015/Task15.182/JavaRuntimeParityDecision.md
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [psobject[]] $Inventory,

    [Parameter()]
    [string] $CanonicalJavaHome = 'C:\Program Files\Eclipse Adoptium\jre-21.0.8.9-hotspot',

    [Parameter()]
    [string] $CanonicalProductCode = '{85726190-68A9-48EF-B05C-D527D32A6C1B}'
  )

  begin {
    $fn = 'Test-ATAPJavaRuntimeParity'
    $mn = 'ATAP.Utilities.IAC.Ansible.Powershell'
    $allInventory = [System.Collections.Generic.List[psobject]]::new()
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting Java runtime parity test.'
  }

  process {
    foreach ($inventoryItem in $Inventory) {
      $allInventory.Add($inventoryItem)
    }
  }

  end {
    $drift = [System.Collections.Generic.List[psobject]]::new()
    $canonicalExe = Join-Path $CanonicalJavaHome 'bin\java.exe'

    foreach ($hostInventory in $allInventory) {
      $hostName = $hostInventory.ComputerName
      $checks = [ordered]@{
        MachineJavaHome = $hostInventory.MachineJavaHome -eq $CanonicalJavaHome
        UserJavaHomeAbsent = [string]::IsNullOrWhiteSpace($hostInventory.UserJavaHome)
        CanonicalJavaFirst = @($hostInventory.JavaCommandPaths).Count -gt 0 -and $hostInventory.JavaCommandPaths[0] -eq $canonicalExe
        OnlyCanonicalProduct = @($hostInventory.InstalledJava).Count -eq 1 -and $hostInventory.InstalledJava[0].PSChildName -eq $CanonicalProductCode
        Java21VendorArchitecture = $hostInventory.JavaRuntimeDetails[0].VersionText -match 'java\.runtime\.version = 21\.0\.8\+9-LTS' -and $hostInventory.JavaRuntimeDetails[0].VersionText -match 'java\.vendor = Eclipse Adoptium' -and $hostInventory.JavaRuntimeDetails[0].VersionText -match 'sun\.arch\.data\.model = 64'
        CanonicalPathFirst = @($hostInventory.MachineJavaPathEntries).Count -gt 0 -and $hostInventory.MachineJavaPathEntries[0].Index -eq 0 -and $hostInventory.MachineJavaPathEntries[0].ExpandedEntry -eq (Join-Path $CanonicalJavaHome 'bin')
        FlywayCompatible = $hostInventory.Flyway.VersionText -match 'Flyway OSS Edition 10\.21\.0' -and $hostInventory.Flyway.VersionText -notmatch 'UnsupportedClassVersionError'
        PlantUmlPresent = @($hostInventory.PlantUmlJarCandidates).Count -gt 0
      }

      foreach ($check in $checks.GetEnumerator()) {
        if (-not $check.Value) {
          $drift.Add([pscustomobject]@{ ComputerName = $hostName; Check = $check.Key })
        }
      }
    }

    [pscustomobject]@{
      ComputerNames = @($allInventory.ComputerName)
      IsCompliant = $drift.Count -eq 0
      Drift = @($drift)
    }
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Finished Java runtime parity test.'
  }
}
