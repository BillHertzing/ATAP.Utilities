Describe 'Get-DocumentationFileInventory' -Tag 'Unit' {
  BeforeAll {
    Import-Module PSFramework -ErrorAction SilentlyContinue
    . (Join-Path $PSScriptRoot '..\..\public\Get-DocumentationFileInventory.ps1')

    $script:fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "DocInvFixture_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:fixtureRoot 'docs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:fixtureRoot 'bin') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:fixtureRoot '_generated\reports') -Force | Out-Null

    Set-Content -Path (Join-Path $script:fixtureRoot 'ReadMe.md') -Value "line1`nline2`nline3"
    Set-Content -Path (Join-Path $script:fixtureRoot 'docs\notes.txt') -Value 'only line'
    Set-Content -Path (Join-Path $script:fixtureRoot 'docs\ignored.cs') -Value 'public class C {}'
    Set-Content -Path (Join-Path $script:fixtureRoot 'bin\excluded.md') -Value 'should be excluded'
    Set-Content -Path (Join-Path $script:fixtureRoot '_generated\reports\gen.md') -Value 'generated but inventoried'
    New-Item -ItemType File -Path (Join-Path $script:fixtureRoot 'docs\empty.md') | Out-Null
    # Fake binary doc: .pdf content is irrelevant; LineCount must be $null regardless
    Set-Content -Path (Join-Path $script:fixtureRoot 'docs\manual.pdf') -Value 'not a real pdf'
  }

  AfterAll {
    if ($script:fixtureRoot -and (Test-Path $script:fixtureRoot)) {
      Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force -Confirm:$false
    }
  }

  Context 'Inclusion, exclusion, and _generated policy' {
    BeforeAll {
      $script:result = @(Get-DocumentationFileInventory -RootPath $script:fixtureRoot)
    }

    It 'returns only documentation-extension files' {
      $script:result.RelativePath | Should -Not -Contain 'docs\ignored.cs'
    }

    It 'excludes files under bin\ by default' {
      $script:result.RelativePath | Should -Not -Contain 'bin\excluded.md'
    }

    It 'includes files under _generated\ (G0 decision: inventoried, review-exempt)' {
      $script:result.RelativePath | Should -Contain '_generated\reports\gen.md'
    }

    It 'finds the expected five documentation files' {
      $script:result | Should -HaveCount 5
    }
  }

  Context 'Record fields' {
    BeforeAll {
      $script:result = @(Get-DocumentationFileInventory -RootPath $script:fixtureRoot)
      $script:readme = $script:result | Where-Object RelativePath -eq 'ReadMe.md'
    }

    It 'defaults RepoName to the root leaf name' {
      $script:readme.RepoName | Should -Be (Split-Path $script:fixtureRoot -Leaf)
    }

    It 'honors an explicit -RepoName' {
      $named = @(Get-DocumentationFileInventory -RootPath $script:fixtureRoot -RepoName 'MyRepo')
      $named[0].RepoName | Should -Be 'MyRepo'
    }

    It 'reports lowercase extension with leading dot' {
      $script:readme.Extension | Should -Be '.md'
    }

    It 'counts lines for text formats' {
      $script:readme.LineCount | Should -Be 3
    }

    It 'reports zero lines for an empty file' {
      ($script:result | Where-Object RelativePath -eq 'docs\empty.md').LineCount | Should -Be 0
    }

    It 'reports null LineCount for binary formats' {
      ($script:result | Where-Object RelativePath -eq 'docs\manual.pdf').LineCount | Should -BeNullOrEmpty
    }

    It 'reports SizeBytes and UTC filesystem timestamps' {
      $script:readme.SizeBytes | Should -BeGreaterThan 0
      $script:readme.FileSystemCreated | Should -BeOfType [datetimeoffset]
      $script:readme.FileSystemLastWrite | Should -BeOfType [datetimeoffset]
      $script:readme.FileSystemCreated.Offset | Should -Be ([timespan]::Zero)
      $script:readme.FileSystemLastWrite.Offset | Should -Be ([timespan]::Zero)
    }
  }

  Context 'Parameter overrides' {
    It 'restricts to the supplied extension list' {
      $mdOnly = @(Get-DocumentationFileInventory -RootPath $script:fixtureRoot -IncludeExtension '.txt')
      $mdOnly | Should -HaveCount 1
      $mdOnly[0].RelativePath | Should -Be 'docs\notes.txt'
    }

    It 'applies a custom exclusion pattern' {
      $noGenerated = @(Get-DocumentationFileInventory -RootPath $script:fixtureRoot -ExcludePathPattern '[\\/](bin|_generated)([\\/]|$)')
      $noGenerated.RelativePath | Should -Not -Contain '_generated\reports\gen.md'
    }

    It 'throws on a nonexistent root' {
      { Get-DocumentationFileInventory -RootPath (Join-Path $script:fixtureRoot 'no-such-dir') } | Should -Throw
    }
  }
}
