Describe 'Export-DocumentationInventory and Invoke-DocumentationInventory' -Tag 'Unit' {
  BeforeAll {
    Import-Module PSFramework -ErrorAction SilentlyContinue
    . (Join-Path $PSScriptRoot '..\..\public\Get-DocumentationFileInventory.ps1')
    . (Join-Path $PSScriptRoot '..\..\public\Get-GitFileDates.ps1')
    . (Join-Path $PSScriptRoot '..\..\public\Export-DocumentationInventory.ps1')
    . (Join-Path $PSScriptRoot '..\..\public\Invoke-DocumentationInventory.ps1')

    $script:expectedHeader = 'RepoName,RelativePath,Extension,SizeBytes,LineCount,' +
      'CreatedNoEarlierThanUtc,CreatedNoLaterThanUtc,CreatedActualUtc,' +
      'LastWriteNoEarlierThanUtc,LastWriteNoLaterThanUtc,LastWriteActualUtc,' +
      'CommitCount,IsTracked'

    $script:fixtureBase = Join-Path ([System.IO.Path]::GetTempPath()) "DocExpFixture_$([guid]::NewGuid().ToString('N'))"
    $script:repoRoot = Join-Path $script:fixtureBase 'RepoA'
    New-Item -ItemType Directory -Path $script:repoRoot -Force | Out-Null
    & git -C $script:repoRoot init --quiet
    & git -C $script:repoRoot config user.email 'fixture@example.test'
    & git -C $script:repoRoot config user.name 'Fixture'
    Set-Content -Path (Join-Path $script:repoRoot 'ReadMe.md') -Value "one`ntwo"
    & git -C $script:repoRoot add -A
    $env:GIT_AUTHOR_DATE = '2024-02-20T08:00:00-06:00'   # = 2024-02-20T14:00:00Z
    $env:GIT_COMMITTER_DATE = '2024-02-20T08:00:00-06:00'
    & git -C $script:repoRoot commit --quiet -m 'initial'
    Remove-Item Env:\GIT_AUTHOR_DATE, Env:\GIT_COMMITTER_DATE -ErrorAction SilentlyContinue
    Set-Content -Path (Join-Path $script:repoRoot 'untracked.md') -Value 'never committed'

    $script:outDir = Join-Path $script:fixtureBase 'out'
  }

  AfterAll {
    if ($script:fixtureBase -and (Test-Path $script:fixtureBase)) {
      Remove-Item -LiteralPath $script:fixtureBase -Recurse -Force -Confirm:$false
    }
  }

  Context 'Export-DocumentationInventory without SprintStartUtc (historical corpus)' {
    BeforeAll {
      $script:summary = Export-DocumentationInventory `
        -Root @(@{ RepoName = 'RepoA'; RootPath = $script:repoRoot }) `
        -OutputDirectory $script:outDir
      $script:rows = Import-Csv $script:summary.CsvPath
    }

    It 'returns an accurate summary object' {
      $script:summary.RootCount | Should -Be 1
      $script:summary.FileCount | Should -Be 2
      $script:summary.UntrackedCount | Should -Be 1
    }

    It 'writes a CSV with the stable §3a column order' {
      $header = (Get-Content $script:summary.CsvPath -TotalCount 1) -replace '"', ''
      $header | Should -Be $script:expectedHeader
    }

    It 'writes one JSON object per line in the JSONL copy' {
      $lines = Get-Content $script:summary.JsonlPath
      $lines | Should -HaveCount 2
      foreach ($line in $lines) { { $line | ConvertFrom-Json } | Should -Not -Throw }
    }

    It 'gives a tracked historical file git bounds in UTC and NO actual values' {
      $tracked = $script:rows | Where-Object RelativePath -eq 'ReadMe.md'
      $tracked.IsTracked | Should -Be 'True'
      $tracked.CreatedNoLaterThanUtc | Should -Be '2024-02-20T14:00:00+00:00'
      $tracked.LastWriteNoLaterThanUtc | Should -Be '2024-02-20T14:00:00+00:00'
      $tracked.CreatedNoEarlierThanUtc | Should -BeNullOrEmpty   # root commit
      $tracked.CreatedActualUtc | Should -BeNullOrEmpty
      $tracked.LastWriteActualUtc | Should -BeNullOrEmpty
      $tracked.CommitCount | Should -Be '1'
    }

    It 'gives an untracked file actual values from the filesystem and no git bounds' {
      $untracked = $script:rows | Where-Object RelativePath -eq 'untracked.md'
      $untracked.IsTracked | Should -Be 'False'
      $untracked.CreatedNoLaterThanUtc | Should -BeNullOrEmpty
      $untracked.CreatedActualUtc | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00$'
      $untracked.LastWriteActualUtc | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00$'
      $untracked.CommitCount | Should -Be '0'
    }

    It 'throws on a root entry without RepoName/RootPath' {
      { Export-DocumentationInventory -Root @(@{ Wrong = 'shape' }) -OutputDirectory $script:outDir } |
        Should -Throw '*RepoName and RootPath*'
    }
  }

  Context 'Export-DocumentationInventory with SprintStartUtc (sprint-created files get actuals)' {
    It 'populates both actual fields for a file first committed on/after sprint start' {
      $summary = Export-DocumentationInventory `
        -Root @(@{ RepoName = 'RepoA'; RootPath = $script:repoRoot }) `
        -OutputDirectory (Join-Path $script:fixtureBase 'out-sprint') `
        -SprintStartUtc ([datetimeoffset]::Parse('2024-01-01T00:00:00+00:00'))
      $rows = Import-Csv $summary.CsvPath
      $tracked = $rows | Where-Object RelativePath -eq 'ReadMe.md'
      $tracked.CreatedActualUtc | Should -Match '\+00:00$'
      $tracked.LastWriteActualUtc | Should -Match '\+00:00$'
      # bounds are still present alongside actuals
      $tracked.CreatedNoLaterThanUtc | Should -Be '2024-02-20T14:00:00+00:00'
    }

    It 'populates no actual fields for tracked files when sprint start post-dates all commits' {
      $summary = Export-DocumentationInventory `
        -Root @(@{ RepoName = 'RepoA'; RootPath = $script:repoRoot }) `
        -OutputDirectory (Join-Path $script:fixtureBase 'out-future') `
        -SprintStartUtc ([datetimeoffset]::Parse('2030-01-01T00:00:00+00:00'))
      $rows = Import-Csv $summary.CsvPath
      $tracked = $rows | Where-Object RelativePath -eq 'ReadMe.md'
      $tracked.CreatedActualUtc | Should -BeNullOrEmpty
      $tracked.LastWriteActualUtc | Should -BeNullOrEmpty
    }
  }

  Context 'Invoke-DocumentationInventory (config-driven driver)' {
    BeforeAll {
      $script:configDir = Join-Path $script:fixtureBase 'config'
      New-Item -ItemType Directory -Path $script:configDir -Force | Out-Null
      $config = @{
        activeRoots    = @(
          @{ repoName = 'RepoA'; rootPath = $script:repoRoot },
          @{ repoName = 'MissingRepo'; rootPath = (Join-Path $script:fixtureBase 'does-not-exist') }
        )
        sprintStartUtc = '2024-01-01T00:00:00+00:00'
        outputs        = @{
          curatedDirectory  = 'Inventory'
          evidenceDirectory = 'Evidence'
        }
      }
      $script:configPath = Join-Path $script:configDir 'ReviewConfig.json'
      $config | ConvertTo-Json -Depth 5 | Set-Content -Path $script:configPath
      $script:driverSummary = Invoke-DocumentationInventory -ConfigPath $script:configPath
    }

    It 'inventories the existing root and skips the missing one' {
      $script:driverSummary.FileCount | Should -Be 2
    }

    It 'passes sprintStartUtc through to the actual-field rules' {
      $rows = Import-Csv $script:driverSummary.CsvPath
      ($rows | Where-Object RelativePath -eq 'ReadMe.md').CreatedActualUtc | Should -Match '\+00:00$'
    }

    It 'writes curated outputs with stable names relative to the config' {
      $script:driverSummary.CsvPath | Should -Be (Join-Path $script:configDir 'Inventory\DocumentationInventory.csv')
      Test-Path $script:driverSummary.CsvPath | Should -BeTrue
    }

    It 'writes datestamped evidence copies' {
      $script:driverSummary.EvidenceCsvPath | Should -Match 'DocumentationInventory-\d{8}-\d{6}\.csv$'
      Test-Path $script:driverSummary.EvidenceCsvPath | Should -BeTrue
      Test-Path $script:driverSummary.EvidenceJsonlPath | Should -BeTrue
    }

    It 'throws when no active root resolves' {
      $badConfig = @{
        activeRoots = @(@{ repoName = 'Nope'; rootPath = (Join-Path $script:fixtureBase 'nope') })
        outputs     = @{ curatedDirectory = 'Inventory'; evidenceDirectory = 'Evidence' }
      }
      $badPath = Join-Path $script:configDir 'BadConfig.json'
      $badConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $badPath
      { Invoke-DocumentationInventory -ConfigPath $badPath } | Should -Throw '*no active roots*'
    }
  }
}
