# ============================================================================
# RETIRED (Task 9.21, Sprint 0009). This integration test exercised creating and
# retrieving a `dbConnectionString-*` CI secret through the PERSONAL-vault bw CLI
# round-trip — exactly the pattern Task 9.21 prohibits. Get-SecretATAPBitwarden
# now refuses CI/infra secret names (connection strings, API keys, ProGet/
# BuildMaster/service-account secrets); they must be read from Bitwarden Secrets
# Manager via Get-SecretATAP. Moved out of tests/ so it no longer runs. Kept for
# history only.
# ============================================================================

# Pester integration tests for Get-SecretATAPBitwarden — long-hyphenated name round-trip
#
# Replaces Get-BitwardenSecret.Integration.Tests.ps1 after the rename and the bw-CLI
# rewrite. The function no longer uses Microsoft.PowerShell.SecretManagement, so the
# 'Bitwarden vault registered via SecretManagement' precondition is dropped — the only
# remaining requirements are the bw CLI on PATH and a valid BW_SESSION.
#
# The round-trip below exercises the same path New-SprintBitwardenSecrets uses:
#   1. Create a Secure Note via bw create item (long hyphenated name)
#   2. Retrieve its notes body via Get-SecretATAPBitwarden -SecretField 'notes'
#   3. Delete the item and verify removal
#
# AI assisted using ./claude/Rules/Powershell.md and pesterTest.instructions.md as guidelines

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Get-SecretATAPBitwarden.ps1')

  # --- Prerequisite checks ---

  # Read BW_SESSION from User scope if not in process scope (R-10 pattern).
  $script:bwSession = $env:BW_SESSION
  if ([string]::IsNullOrWhiteSpace($script:bwSession)) {
    $script:bwSession = [System.Environment]::GetEnvironmentVariable('BW_SESSION', 'User')
  }

  $script:hasBwCli = [bool](Get-Command -Name 'bw' -ErrorAction SilentlyContinue)
  $script:hasBwSession = -not [string]::IsNullOrWhiteSpace($script:bwSession)

  $script:skipReason = $null
  if (-not $script:hasBwCli) {
    $script:skipReason = 'Bitwarden CLI (bw) is not available on PATH'
  } elseif (-not $script:hasBwSession) {
    $script:skipReason = 'BW_SESSION is not set in process or User scope'
  }

  if ($script:hasBwSession) {
    $env:BW_SESSION = $script:bwSession
  }

  $shortGuid = [guid]::NewGuid().ToString('N').Substring(0, 8)
  $script:testSecretName = "dbConnectionString-ATAPUtilities-localhost-Development-PESTERTEST-${shortGuid}"
  $script:testConnStr = 'Server=localhost\Development;Database=ATAPUtilities;Integrated Security=True;' +
  'MultipleActiveResultSets=True;Application Name=ATAPUtilities-Sprint-TEST-Development;TrustServerCertificate=True;'
  $script:createdItemId = $null
}

AfterAll {
  if (-not [string]::IsNullOrWhiteSpace($script:createdItemId) -and $script:hasBwSession -and $script:hasBwCli) {
    $env:BW_SESSION = $script:bwSession
    Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName 'Get-SecretATAPBitwarden.Integration.Tests' {
      & bw delete item $script:createdItemId --session $env:BW_SESSION 2>&1
    } | Out-Null
  }
}

Describe 'Get-SecretATAPBitwarden — long-name round-trip' -Tag 'Integration' {

  Context 'Create — long hyphenated sprint-naming-scheme name via bw CLI' {
    It 'Get-SecretATAPBitwarden_LongHyphenatedName_CreatesSecureNoteWithoutError' {
      if ($script:skipReason) {
        Set-ItResult -Skipped -Because $script:skipReason
        return
      }

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

      $encoded = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName 'Get-SecretATAPBitwarden.Integration.Tests' {
        $itemJson | & bw encode --session $env:BW_SESSION
      }
      $encodeExit = $LASTEXITCODE

      $createOutput = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName 'Get-SecretATAPBitwarden.Integration.Tests' {
        $encoded | & bw create item --session $env:BW_SESSION 2>&1
      }
      $createExit = $LASTEXITCODE

      $encodeExit | Should -Be 0 -Because 'bw encode must succeed'
      $createExit | Should -Be 0 -Because 'bw create item must succeed'

      $created = $createOutput | ConvertFrom-Json -ErrorAction Stop
      $script:createdItemId = $created.id

      $script:createdItemId | Should -Not -BeNullOrEmpty -Because 'a new Bitwarden item ID must be returned'
    }
  }

  Context 'Retrieve — Get-SecretATAPBitwarden must handle hyphens and arbitrary username segments' {
    It 'Get-SecretATAPBitwarden_LongHyphenatedName_DefaultFieldReturnsNotesForSecureNote' {
      if ($script:skipReason -or [string]::IsNullOrWhiteSpace($script:createdItemId)) {
        Set-ItResult -Skipped -Because ($script:skipReason ?? 'Create step was skipped or failed')
        return
      }

      # Default SecretField is 'password'; for a Secure Note this maps to the notes body.
      $result = Get-SecretATAPBitwarden -SecretName $script:testSecretName

      $result | Should -Not -BeNullOrEmpty
      $result | Should -Be $script:testConnStr -Because 'the default field on a Secure Note must return the notes body'
    }

    It 'Get-SecretATAPBitwarden_LongHyphenatedName_ExplicitNotesFieldMatches' {
      if ($script:skipReason -or [string]::IsNullOrWhiteSpace($script:createdItemId)) {
        Set-ItResult -Skipped -Because ($script:skipReason ?? 'Create step was skipped or failed')
        return
      }

      $result = Get-SecretATAPBitwarden -SecretName $script:testSecretName -SecretField 'notes'
      $result | Should -Be $script:testConnStr
    }
  }

  Context 'Delete — clean up test item and verify removal' {
    It 'Get-SecretATAPBitwarden_LongHyphenatedName_DeletedItemIsNoLongerRetrievable' {
      if ($script:skipReason -or [string]::IsNullOrWhiteSpace($script:createdItemId)) {
        Set-ItResult -Skipped -Because ($script:skipReason ?? 'Create step was skipped or failed')
        return
      }

      $idToDelete = $script:createdItemId

      $null = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName 'Get-SecretATAPBitwarden.Integration.Tests' {
        & bw delete item $idToDelete --session $env:BW_SESSION 2>&1
      }
      $deleteExit = $LASTEXITCODE

      $script:createdItemId = $null

      $deleteExit | Should -Be 0 -Because 'bw delete item must succeed'

      $listOutput = Invoke-BitwardenCliWithCleanTlsEnvironment -FunctionName 'Get-SecretATAPBitwarden.Integration.Tests' {
        & bw list items --search $script:testSecretName --session $env:BW_SESSION 2>&1
      }
      $remaining = $listOutput | ConvertFrom-Json -ErrorAction SilentlyContinue
      $stillPresent = @($remaining | Where-Object { $_.name -eq $script:testSecretName })
      $stillPresent.Count | Should -Be 0 -Because 'the deleted item must no longer appear in bw list output'
    }
  }
}
