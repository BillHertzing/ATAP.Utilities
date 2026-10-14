#Requires -Version 7.0

BeforeAll {
  $script:sourceRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
  $script:configRootKeysSource = Join-Path $script:sourceRoot 'ATAP.Utilities.ConfigRootKeys.Powershell\public\Set-CoreConfigRootKeys.ps1'
  $script:perMachineSource = Join-Path $script:sourceRoot 'ATAP.Utilities.PowerShell\Profiles\global_PerMachineSettings.ps1'
  $script:environmentSource = Join-Path $script:sourceRoot 'ATAP.Utilities.PowerShell\Profiles\global_EnvironmentVariables.ps1'

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
    $script:createdWritePSFMessageStub = $true
  }

  $script:savedConfigRootKeys = $global:configRootKeys
  $script:savedPerMachineSettings = $global:PerMachineSettings
  $script:savedSettings = $global:Settings
  $script:savedEnvVars = $global:EnvVars
  $script:savedHostname = $env:hostname

  . $script:configRootKeysSource
  Set-CoreConfigRootKeys -Confirm:$false
}

AfterAll {
  $global:configRootKeys = $script:savedConfigRootKeys
  $global:PerMachineSettings = $script:savedPerMachineSettings
  $global:Settings = $script:savedSettings
  $global:EnvVars = $script:savedEnvVars
  $env:hostname = $script:savedHostname
  if ($script:createdWritePSFMessageStub) {
    Remove-Item -LiteralPath 'Function:\Write-PSFMessage' -ErrorAction SilentlyContinue
  }
}

Describe 'Corpus configuration contract' -Tag 'Unit' {
  BeforeEach {
    $global:PerMachineSettings = @{}
    $global:Settings = @{}
    $global:EnvVars = @{}
    $env:hostname = $script:savedHostname
  }

  It 'publishes the exact UTAT01 defaults without activating the environment' {
    $env:hostname = 'utat01'
    $before = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process')

    . $script:perMachineSource

    $global:PerMachineSettings['ArtifactsPath'] | Should -BeExactly 'C:\ATAPArtifacts'
    $global:PerMachineSettings['CorpusAIConversationPath'] | Should -BeExactly 'C:\ATAPArtifacts\CorpusAIConversation'
    $global:PerMachineSettings['CorpusGatherRecordsPath'] | Should -BeExactly 'C:\ATAPArtifacts\CorpusGatherRecords'
    $global:PerMachineSettings['CorpusGatherRecordsStagingPath'] | Should -BeExactly 'C:\ATAPArtifacts\CorpusGatherRecordsStaging'
    $global:PerMachineSettings['ConversationCorpusReconciliationInterval'] | Should -Be ([TimeSpan]::FromMinutes(15))
    $global:PerMachineSettings['ConversationCorpusScrubInterval'] | Should -Be ([TimeSpan]::FromDays(1))
    [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process') | Should -BeExactly $before
  }

  It 'publishes the exact UTAT022 defaults without activating the environment' {
    $env:hostname = 'utat022'
    $before = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process')

    . $script:perMachineSource

    $global:PerMachineSettings['ArtifactsPath'] | Should -BeExactly 'D:\ATAPArtifacts'
    $global:PerMachineSettings['CorpusAIConversationPath'] | Should -BeExactly 'D:\ATAPArtifacts\CorpusAIConversation'
    $global:PerMachineSettings['CorpusGatherRecordsPath'] | Should -BeExactly 'D:\ATAPArtifacts\CorpusGatherRecords'
    $global:PerMachineSettings['CorpusGatherRecordsStagingPath'] | Should -BeExactly 'D:\ATAPArtifacts\CorpusGatherRecordsStaging'
    $global:PerMachineSettings['ConversationCorpusReconciliationInterval'] | Should -Be ([TimeSpan]::FromMinutes(15))
    $global:PerMachineSettings['ConversationCorpusScrubInterval'] | Should -Be ([TimeSpan]::FromDays(1))
    [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process') | Should -BeExactly $before
  }

  It 'does not publish corpus defaults for another known host' {
    $env:hostname = 'ncat041'

    . $script:perMachineSource

    $global:PerMachineSettings.ContainsKey('ArtifactsPath') | Should -BeFalse
    $global:PerMachineSettings.ContainsKey('CorpusAIConversationPath') | Should -BeFalse
    $global:PerMachineSettings.ContainsKey('CorpusGatherRecordsPath') | Should -BeFalse
    $global:PerMachineSettings.ContainsKey('CorpusGatherRecordsStagingPath') | Should -BeFalse
  }

  It 'projects ARTIFACTS_PATH from the canonical setting without mutating the process' {
    $global:Settings['ArtifactsPath'] = 'C:\ATAPArtifacts'
    $before = [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process')

    . $script:environmentSource

    $global:EnvVars['ARTIFACTS_PATH'] | Should -BeExactly $global:Settings['ArtifactsPath']
    [Environment]::GetEnvironmentVariable('ARTIFACTS_PATH', 'Process') | Should -BeExactly $before
  }

  It 'does not infer ARTIFACTS_PATH when the canonical setting is absent' {
    . $script:environmentSource

    $global:EnvVars.ContainsKey('ARTIFACTS_PATH') | Should -BeFalse
  }

  It 'rejects a relative artifact root' {
    $source = (Get-Content -LiteralPath $script:perMachineSource -Raw).Replace("'C:\ATAPArtifacts'", "'relative\ATAPArtifacts'")

    { [scriptblock]::Create($source).Invoke() } | Should -Throw '*requires an absolute ArtifactsPath*'
  }

  It 'rejects an artifact root under Dropbox' {
    $source = (Get-Content -LiteralPath $script:perMachineSource -Raw).Replace("'C:\ATAPArtifacts'", "'C:\Dropbox\ATAPArtifacts'")

    { [scriptblock]::Create($source).Invoke() } | Should -Throw '*cannot place ArtifactsPath under Dropbox*'
  }

  It 'rejects a missing exact key even when a close variant is present' {
    $source = Get-Content -LiteralPath $script:perMachineSource -Raw
    $hostIndex = $source.IndexOf("'utat01'", [StringComparison]::Ordinal)
    $canonicalKey = "'CorpusAIConversationPathConfigRootKey'"
    $keyIndex = $source.IndexOf($canonicalKey, $hostIndex, [StringComparison]::Ordinal)
    $keyIndex | Should -BeGreaterThan -1
    $source = $source.Remove($keyIndex, $canonicalKey.Length).Insert($keyIndex, "'CorpusAIConversationsPathConfigRootKey'")

    { [scriptblock]::Create($source).Invoke() } | Should -Throw
  }

  It 'rejects zero and negative reconciliation intervals' -ForEach @(
    @{ Expression = '[TimeSpan]::Zero' }
    @{ Expression = '[TimeSpan]::FromMinutes(-1)' }
    @{ Expression = "'not-an-interval'" }
  ) {
    $source = (Get-Content -LiteralPath $script:perMachineSource -Raw).Replace('[TimeSpan]::FromMinutes(15)', $Expression)

    { [scriptblock]::Create($source).Invoke() } | Should -Throw '*requires a positive TimeSpan value*'
  }

  It 'rejects zero and negative scrub intervals' -ForEach @(
    @{ Expression = '[TimeSpan]::Zero' }
    @{ Expression = '[TimeSpan]::FromDays(-1)' }
    @{ Expression = "'not-an-interval'" }
  ) {
    $source = (Get-Content -LiteralPath $script:perMachineSource -Raw).Replace('[TimeSpan]::FromDays(1)', $Expression)

    { [scriptblock]::Create($source).Invoke() } | Should -Throw '*requires a positive TimeSpan value*'
  }
}
