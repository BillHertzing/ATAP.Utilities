BeforeAll {
  . "$PSScriptRoot\..\..\public\Test-PairedAgentTextSuite.ps1"
}

Describe 'Test-PairedAgentTextSuite [public]' -Tag 'Unit' {
  AfterEach {
    Remove-Item Function:\Get-AgentTextFromDatabase -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name pairedBody, pairedHash -Scope Global -ErrorAction SilentlyContinue
  }

  It 'skips when no database connection string is supplied' {
    $result = Test-PairedAgentTextSuite -SuiteName DatabaseDataPresence `
      -SourceId 'ai.core.main' -Tier Development

    $result.Status | Should -Be 'Skipped'
  }

  It 'passes round-trip validation when the stored body hash matches' {
    $global:pairedBody = 'canonical text'
    $bytes = [Text.Encoding]::UTF8.GetBytes($global:pairedBody)
    $global:pairedHash = [Convert]::ToHexString(
      [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
    function global:Get-AgentTextFromDatabase {
      [pscustomobject]@{
        BodyText = $global:pairedBody
        BodySha256 = $global:pairedHash
        Kind = 'Instruction'
      }
    }

    $result = Test-PairedAgentTextSuite -SuiteName AgentTextRoundTrip `
      -ConnectionString 'fixture' -SourceId 'ai.core.main' -Tier Development

    $result.Status | Should -Be 'Passed'
  }
}
