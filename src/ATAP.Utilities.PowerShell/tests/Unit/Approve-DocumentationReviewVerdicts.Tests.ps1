Describe 'Approve-DocumentationReviewVerdicts' -Tag 'Unit' {
  BeforeAll {
    Import-Module PSFramework -ErrorAction SilentlyContinue
    . (Join-Path $PSScriptRoot '..\..\public\Approve-DocumentationReviewVerdicts.ps1')

    $script:fixtureBase = Join-Path ([System.IO.Path]::GetTempPath()) "ApproveFixture_$([guid]::NewGuid().ToString('N'))"
    $script:repoRoot = Join-Path $script:fixtureBase 'RepoA'
    New-Item -ItemType Directory -Path $script:repoRoot -Force | Out-Null
    Set-Content -Path (Join-Path $script:repoRoot 'stale.md') -Value "old content`nline two"
    Set-Content -Path (Join-Path $script:repoRoot 'stub.md') -Value 'just a heading'

    $script:configPath = Join-Path $script:fixtureBase 'ReviewConfig.json'
    @{ activeRoots = @(@{ repoName = 'RepoA'; rootPath = $script:repoRoot }) } |
      ConvertTo-Json -Depth 4 | Set-Content -Path $script:configPath

    $script:registerTemplate = @(
      [PSCustomObject]@{ BatchId = 'DR-Batch-001'; RepoName = 'RepoA'; RelativePath = 'stale.md'; Verdict = 'MINOR-DRIFT'; FindingSummary = 'stale ref'; Evidence = 'checked'; ReviewedUtc = '2026-07-14T00:00:00+00:00'; VerificationStatus = 'verified'; CoordinatorNote = '' }
      [PSCustomObject]@{ BatchId = 'DR-Batch-001'; RepoName = 'RepoA'; RelativePath = 'stub.md'; Verdict = 'INCOMPLETE-STUB'; FindingSummary = 'thin'; Evidence = 'one line'; ReviewedUtc = '2026-07-14T00:00:00+00:00'; VerificationStatus = 'accepted-unsampled'; CoordinatorNote = '' }
      [PSCustomObject]@{ BatchId = 'DR-Batch-002'; RepoName = 'RepoA'; RelativePath = 'gone.md'; Verdict = 'MAJOR-DRIFT'; FindingSummary = 'already fixed'; Evidence = 'x'; ReviewedUtc = '2026-07-14T00:00:00+00:00'; VerificationStatus = 'verified-remediated'; CoordinatorNote = 'REMEDIATED' }
    )
  }

  AfterAll {
    if ($script:fixtureBase -and (Test-Path $script:fixtureBase)) {
      Remove-Item -LiteralPath $script:fixtureBase -Recurse -Force -Confirm:$false
    }
  }

  BeforeEach {
    $script:registerPath = Join-Path $script:fixtureBase "register_$([guid]::NewGuid().ToString('N')).csv"
    $script:registerTemplate | Export-Csv -LiteralPath $script:registerPath -NoTypeInformation -Encoding utf8
  }

  It 'accepts on Y and holds on N, skipping remediated rows' {
    Mock Read-Host { if ($script:callCount++ -eq 0) { 'Y' } else { 'N' } }
    Mock Write-Host {}
    $script:callCount = 0
    $summary = Approve-DocumentationReviewVerdicts -RegisterPath $script:registerPath -ConfigPath $script:configPath
    $summary.Presented | Should -Be 2   # remediated row skipped
    $summary.Accepted | Should -Be 1
    $summary.Held | Should -Be 1
    $after = Import-Csv $script:registerPath
    ($after | Where-Object RelativePath -eq 'stale.md').AcceptanceStatus | Should -Be 'accepted'
    ($after | Where-Object RelativePath -eq 'stale.md').AcceptedUtc | Should -Match '\+00:00$'
    ($after | Where-Object RelativePath -eq 'stub.md').AcceptanceStatus | Should -Be 'held'
    ($after | Where-Object RelativePath -eq 'gone.md').AcceptanceStatus | Should -BeNullOrEmpty
  }

  It 're-prompts until input is Y or N' {
    Mock Write-Host {}
    Mock Read-Host { @('maybe', 'x', 'y')[[Math]::Min($script:promptCount++, 2)] }
    $script:promptCount = 0
    $summary = Approve-DocumentationReviewVerdicts -RegisterPath $script:registerPath -ConfigPath $script:configPath -BatchId 'DR-Batch-001' -Verdict 'MINOR-DRIFT'
    $summary.Presented | Should -Be 1
    $summary.Accepted | Should -Be 1
    Should -Invoke Read-Host -Times 3 -Exactly
  }

  It 'skips held rows unless -IncludeHeld is passed' {
    Mock Write-Host {}
    Mock Read-Host { 'N' }
    Approve-DocumentationReviewVerdicts -RegisterPath $script:registerPath -ConfigPath $script:configPath | Out-Null
    Mock Read-Host { 'Y' }
    $second = Approve-DocumentationReviewVerdicts -RegisterPath $script:registerPath -ConfigPath $script:configPath
    $second.Presented | Should -Be 0
    $third = Approve-DocumentationReviewVerdicts -RegisterPath $script:registerPath -ConfigPath $script:configPath -IncludeHeld
    $third.Presented | Should -Be 2
    $third.Accepted | Should -Be 2
  }

  It 'previews at most PreviewLineCount lines of the file' {
    Mock Read-Host { 'Y' }
    Mock Write-Host {}
    Set-Content -Path (Join-Path $script:repoRoot 'stale.md') -Value ((1..100 | ForEach-Object { "line $_" }) -join "`n")
    Approve-DocumentationReviewVerdicts -RegisterPath $script:registerPath -ConfigPath $script:configPath -BatchId 'DR-Batch-001' -Verdict 'MINOR-DRIFT' -PreviewLineCount 10 | Out-Null
    Should -Invoke Write-Host -ParameterFilter { $Object -like '  | line 10' } -Times 1
    Should -Invoke Write-Host -ParameterFilter { $Object -like '  | line 11' } -Times 0
  }
}
