function Get-ParityPrimaryRole {
<#
.SYNOPSIS
Reads and validates the Dropbox-synchronized DPOM primary-role marker.

.DESCRIPTION
Reads the one shared PrimaryRole.json record and validates the
Task 12.59 schema. The function performs no remoting and returns no output when
the marker does not exist unless ErrorIfMissing is specified.

.PARAMETER StatePath
Dropbox-synchronized ParityState folder containing the single PrimaryRole.json
record shared by both hosts.

.PARAMETER ErrorIfMissing
Throw when PrimaryRole.json does not exist.

.OUTPUTS
PSCustomObject containing the validated marker.

.EXAMPLE
Get-ParityPrimaryRole -StatePath 'C:\Dropbox\whertzing\ATAP\ParityState'

.NOTES
The marker must not contain credentials or secret values.

.LINK
https://github.com/whertzing/ATAP.Utilities
#>
  [CmdletBinding(SupportsShouldProcess = $true)]
  [OutputType([PSCustomObject])]
  param(
    [string] $StatePath = 'C:\Dropbox\whertzing\ATAP\ParityState',

    [switch] $ErrorIfMissing
  )

  begin {
    $fn = 'Get-ParityPrimaryRole'
    $mn = 'ATAP.Utilities.SystemParityMonitor.PowerShell'
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Starting primary-role marker read.'
  }

  process {
    $jsonDocument = $null
    try {
      $markerPath = Join-Path $StatePath 'PrimaryRole.json'
      if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        if ($ErrorIfMissing) {
          throw "Primary-role marker does not exist: $markerPath"
        }
        return $null
      }

      $rawJson = [IO.File]::ReadAllText($markerPath)
      $jsonDocument = [Text.Json.JsonDocument]::Parse($rawJson)
      $marker = $rawJson | ConvertFrom-Json
      $propertyNames = @($marker.PSObject.Properties.Name)
      foreach ($requiredProperty in @('SchemaVersion', 'PrimaryRole', 'PlannedAbsence', 'AuthorizedBy', 'JournalEntryId')) {
        if ($requiredProperty -notin $propertyNames) {
          throw "Primary-role marker '$markerPath' is missing required property '$requiredProperty'."
        }
      }

      if ([int] $marker.SchemaVersion -ne 1) {
        throw "Primary-role marker '$markerPath' has unsupported SchemaVersion '$($marker.SchemaVersion)'."
      }
      if ([string]::IsNullOrWhiteSpace([string] $marker.PrimaryRole)) {
        throw "Primary-role marker '$markerPath' has an empty PrimaryRole."
      }
      if ([string]::IsNullOrWhiteSpace([string] $marker.AuthorizedBy)) {
        throw "Primary-role marker '$markerPath' has an empty AuthorizedBy."
      }

      $journalEntryId = [guid]::Empty
      if (-not [guid]::TryParse([string] $marker.JournalEntryId, [ref] $journalEntryId)) {
        throw "Primary-role marker '$markerPath' has an invalid JournalEntryId."
      }

      if ($null -ne $marker.PlannedAbsence) {
        $absencePropertyNames = @($marker.PlannedAbsence.PSObject.Properties.Name)
        foreach ($requiredProperty in @('HostName', 'SinceUtc', 'Reason')) {
          if ($requiredProperty -notin $absencePropertyNames -or [string]::IsNullOrWhiteSpace([string] $marker.PlannedAbsence.$requiredProperty)) {
            throw "Primary-role marker '$markerPath' has an invalid PlannedAbsence.$requiredProperty."
          }
        }

        if ([string] $marker.PrimaryRole -ieq [string] $marker.PlannedAbsence.HostName) {
          throw "Primary-role marker '$markerPath' cannot name the primary host as the planned-absence host."
        }

        $sinceUtc = [DateTimeOffset]::MinValue
        $sinceUtcText = $jsonDocument.RootElement.GetProperty('PlannedAbsence').GetProperty('SinceUtc').GetString()
        $isValidTimestamp = [DateTimeOffset]::TryParse(
          $sinceUtcText,
          [Globalization.CultureInfo]::InvariantCulture,
          [Globalization.DateTimeStyles]::RoundtripKind,
          [ref] $sinceUtc
        )
        if (-not $isValidTimestamp -or $sinceUtc.Offset -ne [TimeSpan]::Zero) {
          throw "Primary-role marker '$markerPath' has a PlannedAbsence.SinceUtc value that is not ISO-8601 UTC."
        }
        $marker.PlannedAbsence.SinceUtc = $sinceUtcText
      }

      $marker
    } catch {
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to read primary-role marker. Exception: $($_.Exception.Message)"
      throw
    } finally {
      if ($null -ne $jsonDocument) {
        $jsonDocument.Dispose()
      }
      Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message 'Leaving primary-role marker read.'
    }
  }

  end {
    Write-ParityMessage -FunctionName $fn -ModuleName $mn -Level Verbose -Message 'Completed primary-role marker read.'
  }
}
