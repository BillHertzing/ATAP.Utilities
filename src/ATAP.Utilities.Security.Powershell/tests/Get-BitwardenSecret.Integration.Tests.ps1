# Pester integration tests for Get-BitwardenSecret — §6.4-1 and §6.4-2
#
# §6.4-1 code-review finding (no test required for this part):
#   Get-BitwardenSecret accepts -SecretName as a plain [string] with only
#   [ValidateNotNullOrWhiteSpace()]. It passes the value unchanged to
#   Get-Secret -Name $SecretName (SecretManagement). No character filtering,
#   regex parsing, or splitting occurs. Therefore names that include hyphens,
#   machine names, and developer usernames — such as:
#     dbConnectionString-ATAPUtilities-HOSTNAME-Development-jsmith
#   — are handled correctly without modification.
#
# §6.4-2 — the tests below perform an idempotent round-trip:
#   1. Create a sprint-style secure note via bw CLI (same path as New-SprintBitwardenSecrets)
#   2. Retrieve it by the long hyphenated name via Get-BitwardenSecret
#   3. Delete it via bw CLI and verify removal
#
# Prerequisites (all checked in BeforeAll; tests skip gracefully if missing):
#   - bw CLI on PATH
#   - BW_SESSION set in process scope or User scope (R-10 pattern)
#   - Bitwarden vault registered under the name 'Bitwarden' via SecretManagement
#
# AI assisted using ./claude/Rules/Powershell.md and pesterTest.instructions.md as guidelines

BeforeAll {
  . (Join-Path $PSScriptRoot '../public/Get-BitwardenSecret.ps1')

  # --- Prerequisite checks ---

  # Read BW_SESSION from User scope if not in process scope (R-10 pattern)
  $script:bwSession = $env:BW_SESSION
  if ([string]::IsNullOrWhiteSpace($script:bwSession)) {
    $script:bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
  }

  $script:hasBwCli = [bool](Get-Command -Name 'bw' -ErrorAction SilentlyContinue)
  $script:hasVault = [bool](Get-SecretVault -Name 'Bitwarden' -ErrorAction SilentlyContinue)
  $script:hasBwSession = -not [string]::IsNullOrWhiteSpace($script:bwSession)

  $script:skipReason = $null
  if (-not $script:hasBwCli) {
    $script:skipReason = 'Bitwarden CLI (bw) is not available on PATH'
  } elseif (-not $script:hasBwSession) {
    $script:skipReason = 'BW_SESSION is not set in process or User scope'
  } elseif (-not $script:hasVault) {
    $script:skipReason = "SecretManagement vault 'Bitwarden' is not registered on this workstation"
  }

  # Ensure process-scope BW_SESSION is set for bw CLI calls below
  if ($script:hasBwSession) {
    $env:BW_SESSION = $script:bwSession
  }

  # Unique test secret name — follows the sprint naming scheme but uses the
  # reserved username 'PESTERTEST' to distinguish test entries from real secrets.
  # The short GUID suffix prevents collisions across parallel test runs.
  $shortGuid = [guid]::NewGuid().ToString('N').Substring(0, 8)
  $script:testSecretName = "dbConnectionString-ATAPUtilities-localhost-Development-PESTERTEST-${shortGuid}"
  $script:testConnStr = 'Server=localhost\Development;Database=ATAPUtilities;Integrated Security=True;' +
  'MultipleActiveResultSets=True;Application Name=ATAPUtilities-Sprint-TEST-Development;TrustServerCertificate=True;'
  $script:createdItemId = $null
}

AfterAll {
  # Safety net: delete the test item if a prior test left it behind
  if (-not [string]::IsNullOrWhiteSpace($script:createdItemId) -and $script:hasBwSession -and $script:hasBwCli) {
    $env:BW_SESSION = $script:bwSession
    & bw delete item $script:createdItemId --session $env:BW_SESSION 2>&1 | Out-Null
    Write-PSFMessage -Level Debug -Message "AfterAll cleanup: deleted Bitwarden test item $($script:createdItemId)"
  }
}

Describe 'Get-BitwardenSecret — sprint-style long-name round-trip' -Tag 'Integration' {

  Context 'Create — using bw CLI with a long hyphenated sprint-naming-scheme name' {
    It 'Get-BitwardenSecret_LongHyphenatedName_CreatesSecureNoteWithoutError' {
      if ($script:skipReason) {
        Set-ItResult -Skipped -Because $script:skipReason
        return
      }

      # Arrange — build Bitwarden item JSON identical to New-SprintBitwardenSecrets
      $bwItem = [ordered]@{
        organizationId = $null
        folderId       = $null
        type           = 2
        name           = $script:testSecretName
        notes          = $script:testConnStr
        secureNote     = [ordered]@{ type = 0 }
        fields         = @()
        reprompt       = 0
      }
      $itemJson = $bwItem | ConvertTo-Json -Depth 5 -Compress

      # Act
      $encoded = $itemJson | & bw encode --session $env:BW_SESSION
      $encodeExit = $LASTEXITCODE

      $createOutput = $encoded | & bw create item --session $env:BW_SESSION 2>&1
      $createExit = $LASTEXITCODE

      # Assert
      $encodeExit | Should -Be 0 -Because 'bw encode must succeed'
      $createExit | Should -Be 0 -Because 'bw create item must succeed'

      $created = $createOutput | ConvertFrom-Json -ErrorAction Stop
      $script:createdItemId = $created.id

      $script:createdItemId | Should -Not -BeNullOrEmpty -Because 'a new Bitwarden item ID must be returned'
    }
  }

  Context 'Retrieve — Get-BitwardenSecret must handle hyphens and arbitrary username segments' {
    It 'Get-BitwardenSecret_LongHyphenatedName_ReturnsNonNullSecret' {
      if ($script:skipReason -or [string]::IsNullOrWhiteSpace($script:createdItemId)) {
        Set-ItResult -Skipped -Because ($script:skipReason ?? 'Create step was skipped or failed')
        return
      }

      # Act — retrieve by the long, hyphenated name (§6.4-1 verification path)
      $result = Get-BitwardenSecret -SecretName $script:testSecretName -AsPlainText

      # Assert
      $result | Should -Not -BeNullOrEmpty -Because 'Get-BitwardenSecret must return the stored secret value'
    }
  }

  Context 'Delete — clean up test item and verify removal' {
    It 'Get-BitwardenSecret_LongHyphenatedName_DeletedItemIsNoLongerRetrievable' {
      if ($script:skipReason -or [string]::IsNullOrWhiteSpace($script:createdItemId)) {
        Set-ItResult -Skipped -Because ($script:skipReason ?? 'Create step was skipped or failed')
        return
      }

      $idToDelete = $script:createdItemId

      # Act — delete via bw CLI
      $deleteOutput = & bw delete item $idToDelete --session $env:BW_SESSION 2>&1
      $deleteExit = $LASTEXITCODE

      # Mark deleted so AfterAll safety net does not double-delete
      $script:createdItemId = $null

      # Assert — deletion succeeded
      $deleteExit | Should -Be 0 -Because 'bw delete item must succeed'

      # Verify the item is gone — bw list should return no exact-name match
      $listOutput = & bw list items --search $script:testSecretName --session $env:BW_SESSION 2>&1
      $remaining = $listOutput | ConvertFrom-Json -ErrorAction SilentlyContinue
      $stillPresent = @($remaining | Where-Object { $_.name -eq $script:testSecretName })
      $stillPresent.Count | Should -Be 0 -Because 'the deleted item must no longer appear in bw list output'
    }
  }
}
