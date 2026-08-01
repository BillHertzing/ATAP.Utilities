function Test-PairedAgentTextSuite {
  <#
  .SYNOPSIS
    Validates AgentText database presence or round-trip integrity.
  .DESCRIPTION
    Runs one AgentText-backed validation suite. DatabaseDataPresence confirms
    that the tier database contains the requested source record.
    AgentTextRoundTrip also verifies that the stored body matches its recorded
    SHA-256 value. The command skips cleanly when no connection string or
    Get-AgentTextFromDatabase command is available.
  #>
  [CmdletBinding()]
  [OutputType([pscustomobject])]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('DatabaseDataPresence', 'AgentTextRoundTrip')]
    [string] $SuiteName,

    [Parameter()]
    [AllowEmptyString()]
    [string] $ConnectionString = '',

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $SourceId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Tier
  )

  process {
    if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
      return [pscustomobject]@{
        Name = $SuiteName
        Status = 'Skipped'
        Detail = 'No -DatabaseConnectionString supplied for this tier.'
      }
    }
    if (-not (Get-Command -Name 'Get-AgentTextFromDatabase' -ErrorAction SilentlyContinue)) {
      return [pscustomobject]@{
        Name = $SuiteName
        Status = 'Skipped'
        Detail = 'Get-AgentTextFromDatabase (RulesManagement.PowerShell) not available in this session.'
      }
    }

    try {
      $records = @(Get-AgentTextFromDatabase -ConnectionString $ConnectionString -SourceId $SourceId)
      if ($records.Count -eq 0) {
        return [pscustomobject]@{
          Name = $SuiteName
          Status = 'Failed'
          Detail = "AgentText SourceId '$SourceId' not present in the '$Tier' database."
        }
      }
      $record = $records[0]

      if ($SuiteName -eq 'DatabaseDataPresence') {
        return [pscustomobject]@{
          Name = $SuiteName
          Status = 'Passed'
          Detail = "AgentText SourceId '$SourceId' present in the '$Tier' database (Kind='$($record.Kind)')."
        }
      }

      $bytes = [System.Text.Encoding]::UTF8.GetBytes([string] $record.BodyText)
      $sha = [System.Security.Cryptography.SHA256]::Create()
      try {
        $hashBytes = $sha.ComputeHash($bytes)
      } finally {
        $sha.Dispose()
      }
      $computed = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
      $stored = ([string] $record.BodySha256).ToLowerInvariant()
      if ($computed -eq $stored) {
        return [pscustomobject]@{
          Name = $SuiteName
          Status = 'Passed'
          Detail = "Round-trip integrity OK for '$SourceId' (sha256 $stored)."
        }
      }
      return [pscustomobject]@{
        Name = $SuiteName
        Status = 'Failed'
        Detail = "Round-trip integrity MISMATCH for '$SourceId': stored=$stored computed=$computed."
      }
    } catch {
      return [pscustomobject]@{
        Name = $SuiteName
        Status = 'Failed'
        Detail = $_.Exception.Message
      }
    }
  }
}
