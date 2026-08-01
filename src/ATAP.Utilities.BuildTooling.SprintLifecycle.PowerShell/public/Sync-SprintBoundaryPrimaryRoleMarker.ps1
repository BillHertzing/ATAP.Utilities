function Sync-SprintBoundaryPrimaryRoleMarker {
<#
.SYNOPSIS
Validates or migrates the Dropbox-synchronized DPOM primary-role marker.

.DESCRIPTION
Keeps PrimaryRole.json at a stable operational path outside Git worktrees.
Sprint Start and End boundaries call this function to validate the shared
marker and, when the shared marker is absent, atomically migrate a lone legacy
marker from the local ProgramData ParityState folder. If local and shared
markers both exist but differ, the function stops for human reconciliation.

.PARAMETER Boundary
Sprint boundary being processed.

.PARAMETER GitRoot
Git repository root below the Dropbox account folder. The shared state path
defaults to <parent-of-GitRoot>\ATAP\ParityState.

.PARAMETER SharedStatePath
Optional explicit Dropbox-synchronized ATAP ParityState folder.

.PARAMETER LegacyStatePath
Legacy machine-local ParityState folder.

.OUTPUTS
PSCustomObject describing the boundary, action, and marker paths.

.EXAMPLE
Sync-SprintBoundaryPrimaryRoleMarker -Boundary Start -GitRoot 'C:\Dropbox\whertzing\GitHub'

.NOTES
This function never changes marker content and never chooses between conflicting
copies. It performs no remoting and records no secrets.

.LINK
Set-SprintBoundaryContext
#>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Start', 'End')]
    [string] $Boundary,

    [string] $GitRoot = 'C:\Dropbox\whertzing\GitHub',

    [string] $SharedStatePath,

    [string] $LegacyStatePath = 'C:\ProgramData\ATAP\ParityState'
  )

  begin {
    $fn = 'Sync-SprintBoundaryPrimaryRoleMarker'
    $mn = 'ATAP.Utilities.BuildTooling.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn (Boundary=$Boundary)"

    if ([string]::IsNullOrWhiteSpace($SharedStatePath)) {
      $dropboxAccountRoot = Split-Path -Path ([IO.Path]::GetFullPath($GitRoot)) -Parent
      $SharedStatePath = Join-Path $dropboxAccountRoot 'ATAP\ParityState'
    }

    $validateMarker = {
      param(
        [Parameter(Mandatory = $true)] $Marker,
        [Parameter(Mandatory = $true)] [string] $MarkerPath
      )

      $propertyNames = @($Marker.PSObject.Properties.Name)
      foreach ($requiredProperty in @('SchemaVersion', 'PrimaryRole', 'PlannedAbsence', 'AuthorizedBy', 'JournalEntryId')) {
        if ($requiredProperty -notin $propertyNames) {
          throw "Primary-role marker '$MarkerPath' is missing required property '$requiredProperty'."
        }
      }
      if ([int] $Marker.SchemaVersion -ne 1 -or
        [string]::IsNullOrWhiteSpace([string] $Marker.PrimaryRole) -or
        [string]::IsNullOrWhiteSpace([string] $Marker.AuthorizedBy)) {
        throw "Primary-role marker '$MarkerPath' has invalid required values."
      }

      $journalEntryId = [guid]::Empty
      if (-not [guid]::TryParse([string] $Marker.JournalEntryId, [ref] $journalEntryId) -or $journalEntryId -eq [guid]::Empty) {
        throw "Primary-role marker '$MarkerPath' has an invalid JournalEntryId."
      }

      $plannedAbsence = $null
      if ($null -ne $Marker.PlannedAbsence) {
        foreach ($requiredProperty in @('HostName', 'SinceUtc', 'Reason')) {
          if ([string]::IsNullOrWhiteSpace([string] $Marker.PlannedAbsence.$requiredProperty)) {
            throw "Primary-role marker '$MarkerPath' has an invalid PlannedAbsence.$requiredProperty."
          }
        }
        if ([string] $Marker.PrimaryRole -ieq [string] $Marker.PlannedAbsence.HostName) {
          throw "Primary-role marker '$MarkerPath' names the primary as the planned-absence host."
        }
        $sinceUtc = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse(
            [string] $Marker.PlannedAbsence.SinceUtc,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind,
            [ref] $sinceUtc
          ) -or $sinceUtc.Offset -ne [TimeSpan]::Zero) {
          throw "Primary-role marker '$MarkerPath' has a PlannedAbsence.SinceUtc value that is not ISO-8601 UTC."
        }
        $plannedAbsence = [ordered] @{
          HostName = [string] $Marker.PlannedAbsence.HostName
          SinceUtc = [string] $Marker.PlannedAbsence.SinceUtc
          Reason = [string] $Marker.PlannedAbsence.Reason
        }
      }

      [ordered] @{
        SchemaVersion = 1
        PrimaryRole = [string] $Marker.PrimaryRole
        PlannedAbsence = $plannedAbsence
        AuthorizedBy = [string] $Marker.AuthorizedBy
        JournalEntryId = $journalEntryId.ToString()
      }
    }
  }

  process {
    $temporaryPath = $null
    try {
      $sharedMarkerPath = Join-Path $SharedStatePath 'PrimaryRole.json'
      $legacyMarkerPath = Join-Path $LegacyStatePath 'PrimaryRole.json'
      $sharedExists = Test-Path -LiteralPath $sharedMarkerPath -PathType Leaf
      $legacyExists = Test-Path -LiteralPath $legacyMarkerPath -PathType Leaf

      $sharedMarker = $null
      $legacyMarker = $null
      if ($sharedExists) {
        $sharedMarker = [IO.File]::ReadAllText($sharedMarkerPath) | ConvertFrom-Json -DateKind String
        $sharedMarker = & $validateMarker -Marker $sharedMarker -MarkerPath $sharedMarkerPath
      }
      if ($legacyExists) {
        $legacyMarker = [IO.File]::ReadAllText($legacyMarkerPath) | ConvertFrom-Json -DateKind String
        $legacyMarker = & $validateMarker -Marker $legacyMarker -MarkerPath $legacyMarkerPath
      }

      if ($sharedExists -and $legacyExists) {
        $sharedCanonical = $sharedMarker | ConvertTo-Json -Depth 8 -Compress
        $legacyCanonical = $legacyMarker | ConvertTo-Json -Depth 8 -Compress
        if ($sharedCanonical -cne $legacyCanonical) {
          throw "Shared and legacy primary-role markers differ. Reconcile '$sharedMarkerPath' and '$legacyMarkerPath' before continuing the sprint boundary."
        }
        $action = 'SharedAndLegacyMatch'
      } elseif ($sharedExists) {
        $action = 'SharedVerified'
      } elseif ($legacyExists) {
        $action = 'MigratedLegacy'
        if ($PSCmdlet.ShouldProcess($sharedMarkerPath, "Migrate legacy primary-role marker for sprint $Boundary")) {
          if (-not (Test-Path -LiteralPath $SharedStatePath -PathType Container)) {
            New-Item -ItemType Directory -Path $SharedStatePath -Force | Out-Null
          }
          $temporaryPath = Join-Path $SharedStatePath ".PrimaryRole.json.$([guid]::NewGuid().ToString('N')).tmp"
          [IO.File]::WriteAllBytes($temporaryPath, [IO.File]::ReadAllBytes($legacyMarkerPath))
          [IO.File]::Move($temporaryPath, $sharedMarkerPath, $false)
        } else {
          $action = 'WhatIfMigrateLegacy'
        }
      } else {
        $action = 'NotPresent'
      }

      [pscustomobject] @{
        Boundary = $Boundary
        Action = $action
        Succeeded = $true
        SharedStatePath = $SharedStatePath
        SharedMarkerPath = $sharedMarkerPath
        LegacyMarkerPath = $legacyMarkerPath
      }
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to synchronize the sprint-boundary primary-role marker. Exception: $($_.Exception.Message)"
      throw
    } finally {
      if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
      }
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Leaving function $fn"
    }
  }

  end {
  }
}
