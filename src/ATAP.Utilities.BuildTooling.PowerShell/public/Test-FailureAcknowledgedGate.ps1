# AI assisted using Powershell.instructions.md as guidelines
function Test-FailureAcknowledgedGate {
  <#
  .SYNOPSIS
    Evaluates the 5-Tier Failure-Acknowledged gate against a Pester JUnit XML result file.

  .DESCRIPTION
    Parses a Pester-produced JUnit XML results file and cross-references each failing
    `<testcase>` against entries in a FailureAcknowledged.json file. A failure is
    considered "acknowledged" when a matching entry exists whose declared tier
    (T1..T5) is at or below the current gate tier (Sprint..Production). The gate
    passes only when every failure is acknowledged.

  .PARAMETER ResultFile
    Path to the Pester JUnit XML result file produced by task T-16.

  .PARAMETER AcknowledgedFile
    Path to FailureAcknowledged.json. If the file does not exist the acknowledgment
    list is treated as empty.

  .PARAMETER Tier
    The gate tier currently being evaluated. One of Sprint, Alpha, Beta, QA, Production.

  .OUTPUTS
    [PSCustomObject] with properties Passed, Failed, Acknowledged, Unacknowledged, GatePass.

  .EXAMPLE
    Test-FailureAcknowledgedGate -ResultFile ./TestResults.xml -AcknowledgedFile ./FailureAcknowledged.json -Tier Beta

  .NOTES
    AI assisted using Powershell.instructions.md as guidelines

  .LINK
    https://docs.pester.dev/
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$ResultFile,

    [Parameter(Mandatory)]
    [string]$AcknowledgedFile,

    [Parameter(Mandatory)]
    [ValidateSet('Sprint', 'Alpha', 'Beta', 'QA', 'Production')]
    [string]$Tier
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = $MyInvocation.MyCommand.ModuleName

    # Map tier name to numeric rank (T1..T5)
    $tierRank = @{
      'Sprint'     = 1
      'Alpha'      = 2
      'Beta'       = 3
      'QA'         = 4
      'Production' = 5
    }
    $gateRank = $tierRank[$Tier]

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Evaluating gate at tier '$Tier' (rank $gateRank) against result file '$ResultFile'"

    if (-not (Test-Path -Path $ResultFile)) {
      throw "ResultFile not found: $ResultFile"
    }
  }

  process {
    try {
      [xml]$resultXml = Get-Content -Path $ResultFile -Raw
    } catch {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to parse ResultFile '$ResultFile' as XML: $_"
      throw
    }

    # Collect every <testcase> element regardless of nesting depth
    $testcases = @($resultXml.SelectNodes('//testcase'))
    $totalCount = $testcases.Count

    $failingTests = @()
    foreach ($tc in $testcases) {
      $hasFailure = $false
      foreach ($child in $tc.ChildNodes) {
        if ($child.LocalName -eq 'failure') {
          $hasFailure = $true
          break
        }
      }
      if ($hasFailure) {
        $failingTests += $tc
      }
    }

    $failedCount = $failingTests.Count
    $passedCount = $totalCount - $failedCount

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "JUnit parse: total=$totalCount passed=$passedCount failed=$failedCount"

    # Load acknowledgment entries (treat missing file as empty)
    $ackEntries = @()
    if (Test-Path -Path $AcknowledgedFile) {
      try {
        $rawJson = Get-Content -Path $AcknowledgedFile -Raw
        if ($rawJson -and $rawJson.Trim().Length -gt 0) {
          $parsed = $rawJson | ConvertFrom-Json
          if ($null -ne $parsed) {
            $ackEntries = @($parsed)
          }
        }
      } catch {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failed to parse AcknowledgedFile '$AcknowledgedFile' as JSON: $_"
        throw
      }
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "AcknowledgedFile '$AcknowledgedFile' does not exist; treating acknowledgment list as empty"
    }

    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Loaded $($ackEntries.Count) acknowledgment entries"

    $acknowledgedCount = 0
    $unacknowledgedTestNames = @()

    foreach ($tc in $failingTests) {
      $tcName = [string]$tc.name
      $tcClass = [string]$tc.classname
      $combined = if ($tcClass) { "$tcClass.$tcName" } else { $tcName }

      $matched = $false
      foreach ($entry in $ackEntries) {
        if ($null -eq $entry) { continue }
        $entryTestName = [string]$entry.testName
        if (-not $entryTestName) { continue }

        $nameMatches = ($entryTestName -eq $tcName) -or ($entryTestName -eq $combined)
        if (-not $nameMatches) { continue }

        # Tier check: entry.tier like 'T2'; must be at or below current gate rank
        $entryTierString = [string]$entry.tier
        $entryRank = $null
        if ($entryTierString -match '^[Tt](\d+)$') {
          $entryRank = [int]$Matches[1]
        }
        if ($null -eq $entryRank) {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Skipping ack entry for '$entryTestName': unparsable tier '$entryTierString'"
          continue
        }

        if ($entryRank -le $gateRank) {
          $matched = $true
          break
        }
      }

      if ($matched) {
        $acknowledgedCount++
      } else {
        $unacknowledgedTestNames += $combined
      }
    }

    $unacknowledgedCount = $failedCount - $acknowledgedCount
    $gatePass = ($unacknowledgedCount -eq 0)

    if (-not $gatePass) {
      $listText = ($unacknowledgedTestNames -join "`n  - ")
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message "Failure-Acknowledged gate FAILED at tier '$Tier': $unacknowledgedCount unacknowledged failure(s):`n  - $listText"
    } else {
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Failure-Acknowledged gate PASSED at tier '$Tier' (acknowledged=$acknowledgedCount failed=$failedCount)"
    }

    return [PSCustomObject]@{
      Passed         = $passedCount
      Failed         = $failedCount
      Acknowledged   = $acknowledgedCount
      Unacknowledged = $unacknowledgedCount
      GatePass       = $gatePass
    }
  }
}
