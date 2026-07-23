#Requires -Version 7.0
# Pester 5+ tests for Start-LocalPowerShellModuleBuildMasterPoller.
# Uses a local throwaway Git repository and mocks BuildMaster API handoff.

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Start-BuildMasterPackagePipeline.ps1')
  . (Join-Path $publicDir 'Start-LocalPowerShellModuleBuildMasterPoller.ps1')

  function Invoke-TestGit {
    param(
      [Parameter(Mandatory = $true)]
      [string]$RepoRoot,

      [Parameter(Mandatory = $true)]
      [string[]]$Arguments
    )

    $output = & git -C $RepoRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "git $($Arguments -join ' ') failed in '$RepoRoot': $($output -join [Environment]::NewLine)"
    }

    return @($output | ForEach-Object { [string]$_ })
  }

  function Get-TestGitScalar {
    param(
      [Parameter(Mandatory = $true)]
      [string]$RepoRoot,

      [Parameter(Mandatory = $true)]
      [string[]]$Arguments
    )

    $lines = @(Invoke-TestGit -RepoRoot $RepoRoot -Arguments $Arguments)
    if ($lines.Count -eq 0) {
      return ''
    }

    return ([string]$lines[0]).Trim()
  }

  function New-LocalPollerTestRepository {
    $repoRoot = Join-Path -Path $TestDrive -ChildPath ([Guid]::NewGuid().ToString('N'))
    $moduleRoot = Join-Path -Path $repoRoot -ChildPath 'src/ATAP.Utilities.BuildTooling.PowerShell'
    New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $moduleRoot -ChildPath 'version.json') -Value '{"version":"0.1.0"}' -Encoding utf8 -NoNewline

    & git -C $repoRoot init -b main 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw 'git init failed for local poller test repository.'
    }

    Invoke-TestGit -RepoRoot $repoRoot -Arguments @('config', 'user.email', 'local-poller@example.test') | Out-Null
    Invoke-TestGit -RepoRoot $repoRoot -Arguments @('config', 'user.name', 'Local Poller Test') | Out-Null
    Invoke-TestGit -RepoRoot $repoRoot -Arguments @('add', '.') | Out-Null
    Invoke-TestGit -RepoRoot $repoRoot -Arguments @('commit', '-m', 'initial') | Out-Null

    return $repoRoot
  }

  function Add-TestCommit {
    param(
      [Parameter(Mandatory = $true)]
      [string]$RepoRoot,

      [Parameter(Mandatory = $true)]
      [string]$RelativePath,

      [Parameter(Mandatory = $true)]
      [string]$Content,

      [Parameter(Mandatory = $true)]
      [string]$Message
    )

    $path = Join-Path -Path $RepoRoot -ChildPath $RelativePath
    $directory = Split-Path -Parent $path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    Set-Content -LiteralPath $path -Value $Content -Encoding utf8 -NoNewline
    Invoke-TestGit -RepoRoot $RepoRoot -Arguments @('add', $RelativePath) | Out-Null
    Invoke-TestGit -RepoRoot $RepoRoot -Arguments @('commit', '-m', $Message) | Out-Null
  }
}

Describe 'Start-LocalPowerShellModuleBuildMasterPoller' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    $script:pipelineCall = $null
    Mock Write-Host { }
    Mock Start-BuildMasterPackagePipeline -MockWith {
      $script:pipelineCall = @{
        Application                     = $Application
        PipelineName                    = $PipelineName
        ModuleName                      = $ModuleName
        PackageName                     = $PackageName
        ProjectPath                     = $ProjectPath
        Tier                            = $Tier
        FeedName                        = $FeedName
        Branch                          = $Branch
        BuildMasterBaseUrl              = $BuildMasterBaseUrl
        BuildMasterAdminApiKeySecretName = $BuildMasterAdminApiKeySecretName
        Reason                          = $Reason
        SkipDeployment                  = $SkipDeployment.IsPresent
      }
      [PSCustomObject]@{
        Succeeded       = $true
        ReleaseNumber   = '0.1.1-alpha'
        BuildNumber     = '42'
        ResponseSummary = 'queued'
      }
    }
  }

  It 'queues the BuildMaster package pipeline when a committed module file changed' {
    $repoRoot = New-LocalPollerTestRepository
    $initialCommit = Get-TestGitScalar -RepoRoot $repoRoot -Arguments @('rev-parse', 'HEAD')
    $statePath = Join-Path -Path $TestDrive -ChildPath 'state-buildtooling.json'
    [PSCustomObject]@{ LastSeenCommit = $initialCommit } | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding utf8 -NoNewline

    Add-TestCommit `
      -RepoRoot $repoRoot `
      -RelativePath 'src/ATAP.Utilities.BuildTooling.PowerShell/public/New-PilotThing.ps1' `
      -Content 'function New-PilotThing {}' `
      -Message 'touch module file'
    $currentCommit = Get-TestGitScalar -RepoRoot $repoRoot -Arguments @('rev-parse', 'HEAD')

    $result = Start-LocalPowerShellModuleBuildMasterPoller `
      -RepoRoot $repoRoot `
      -StatePath $statePath `
      -BuildMasterBaseUrl 'http://localhost:8622' `
      -BuildMasterAdminApiKeySecretName 'BuildMaster.Admin.API.Key.utat01'

    Should -Invoke Start-BuildMasterPackagePipeline -Times 1 -Exactly -Scope It
    $result.Triggered | Should -BeTrue
    $result.StateUpdated | Should -BeTrue
    $result.PreviousCommit | Should -Be $initialCommit
    $result.CurrentCommit | Should -Be $currentCommit
    $result.MatchedFiles | Should -Contain 'src/ATAP.Utilities.BuildTooling.PowerShell/public/New-PilotThing.ps1'
    $script:pipelineCall['ModuleName'] | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell'
    $script:pipelineCall['PackageName'] | Should -Be 'ATAP.Utilities.BuildTooling.PowerShell'
    $script:pipelineCall['ProjectPath'] | Should -Be (Join-Path -Path $repoRoot -ChildPath 'src/ATAP.Utilities.BuildTooling.PowerShell')
    $script:pipelineCall['Tier'] | Should -Be 'Experimental'
    $script:pipelineCall['FeedName'] | Should -Be 'powershellget-experimental'
    $script:pipelineCall['BuildMasterBaseUrl'] | Should -Be 'http://localhost:8622'
    $script:pipelineCall['BuildMasterAdminApiKeySecretName'] | Should -Be 'BuildMaster.Admin.API.Key.utat01'

    $savedState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $savedState.LastSeenCommit | Should -Be $currentCommit
  }

  It 'does not queue the pipeline when only non-module files changed' {
    $repoRoot = New-LocalPollerTestRepository
    $initialCommit = Get-TestGitScalar -RepoRoot $repoRoot -Arguments @('rev-parse', 'HEAD')
    $statePath = Join-Path -Path $TestDrive -ChildPath 'state-docs.json'
    [PSCustomObject]@{ LastSeenCommit = $initialCommit } | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding utf8 -NoNewline

    Add-TestCommit `
      -RepoRoot $repoRoot `
      -RelativePath 'SolutionDocumentation/Some-Runbook.md' `
      -Content '# runbook' `
      -Message 'touch docs'
    $currentCommit = Get-TestGitScalar -RepoRoot $repoRoot -Arguments @('rev-parse', 'HEAD')

    $result = Start-LocalPowerShellModuleBuildMasterPoller -RepoRoot $repoRoot -StatePath $statePath

    Should -Invoke Start-BuildMasterPackagePipeline -Times 0 -Exactly -Scope It
    $result.Triggered | Should -BeFalse
    $result.StateUpdated | Should -BeTrue
    $result.MatchedFiles.Count | Should -Be 0

    $savedState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $savedState.LastSeenCommit | Should -Be $currentCommit
  }

  It 'baselines the current commit without triggering when no state exists' {
    $repoRoot = New-LocalPollerTestRepository
    Add-TestCommit `
      -RepoRoot $repoRoot `
      -RelativePath 'src/ATAP.Utilities.BuildTooling.PowerShell/public/New-PilotThing.ps1' `
      -Content 'function New-PilotThing {}' `
      -Message 'touch module file'
    $currentCommit = Get-TestGitScalar -RepoRoot $repoRoot -Arguments @('rev-parse', 'HEAD')
    $statePath = Join-Path -Path $TestDrive -ChildPath 'state-new.json'

    $result = Start-LocalPowerShellModuleBuildMasterPoller -RepoRoot $repoRoot -StatePath $statePath

    Should -Invoke Start-BuildMasterPackagePipeline -Times 0 -Exactly -Scope It
    $result.StateWasMissing | Should -BeTrue
    $result.Triggered | Should -BeFalse
    $result.StateUpdated | Should -BeTrue
    $result.PreviousCommit | Should -Be $currentCommit

    $savedState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $savedState.LastSeenCommit | Should -Be $currentCommit
  }

  It 'can compare the previous commit on first run when explicitly requested' {
    $repoRoot = New-LocalPollerTestRepository
    Add-TestCommit `
      -RepoRoot $repoRoot `
      -RelativePath 'src/ATAP.Utilities.BuildTooling.PowerShell/public/New-PilotThing.ps1' `
      -Content 'function New-PilotThing {}' `
      -Message 'touch module file'
    $statePath = Join-Path -Path $TestDrive -ChildPath 'state-first-diff.json'

    $result = Start-LocalPowerShellModuleBuildMasterPoller `
      -RepoRoot $repoRoot `
      -StatePath $statePath `
      -UsePreviousCommitWhenStateMissing `
      -SkipDeployment

    Should -Invoke Start-BuildMasterPackagePipeline -Times 1 -Exactly -Scope It
    $result.StateWasMissing | Should -BeTrue
    $result.Triggered | Should -BeTrue
    $result.MatchedFiles | Should -Contain 'src/ATAP.Utilities.BuildTooling.PowerShell/public/New-PilotThing.ps1'
    $script:pipelineCall['SkipDeployment'] | Should -BeTrue
  }
}
