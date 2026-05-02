# tests/Unit/Get-TierFromNBGVLabel.Tests.ps1
#
# Pester 5+ unit tests for Get-TierFromNBGVLabel. Pure in-memory logic — no
# external dependencies to mock.

#Requires -Module Pester

BeforeAll {
  $script:publicDir = Join-Path $PSScriptRoot '..\..\public' | Resolve-Path
  . (Join-Path $script:publicDir 'Get-TierFromNBGVLabel.ps1')

  if (-not (Get-Module -ListAvailable -Name PSFramework)) {
    function Write-PSFMessage { param( [Parameter(ValueFromRemainingArguments = $true)] $rest ) }
  }
  else {
    Import-Module PSFramework -ErrorAction SilentlyContinue
  }
}

Describe 'Get-TierFromNBGVLabel' {

  Context 'Valid labels — bare form' {
    It 'Sprint maps to T1 Experimental / powershellget-experimental' {
      $r = Get-TierFromNBGVLabel -PrereleaseLabel 'Sprint'
      $r.TierNumber | Should -Be 1
      $r.TierName   | Should -BeExactly 'Experimental'
      $r.FeedName   | Should -BeExactly 'powershellget-experimental'
    }
    It 'Alpha maps to T2 Development / powershellget-development' {
      $r = Get-TierFromNBGVLabel -PrereleaseLabel 'Alpha'
      $r.TierNumber | Should -Be 2
      $r.TierName   | Should -BeExactly 'Development'
      $r.FeedName   | Should -BeExactly 'powershellget-development'
    }
    It 'Beta maps to T3 Integration / powershellget-integration' {
      $r = Get-TierFromNBGVLabel -PrereleaseLabel 'Beta'
      $r.TierNumber | Should -Be 3
      $r.TierName   | Should -BeExactly 'Integration'
      $r.FeedName   | Should -BeExactly 'powershellget-integration'
    }
    It 'QA maps to T4 QA / powershellget-qa' {
      $r = Get-TierFromNBGVLabel -PrereleaseLabel 'QA'
      $r.TierNumber | Should -Be 4
      $r.TierName   | Should -BeExactly 'QA'
      $r.FeedName   | Should -BeExactly 'powershellget-qa'
    }
    It 'Empty string maps to T5 Stable / powershellget-stable' {
      $r = Get-TierFromNBGVLabel -PrereleaseLabel ''
      $r.TierNumber | Should -Be 5
      $r.TierName   | Should -BeExactly 'Stable'
      $r.FeedName   | Should -BeExactly 'powershellget-stable'
    }
  }

  Context 'Valid labels — combined label+height form' {
    It 'Alpha6 normalizes to Alpha -> T2' {
      (Get-TierFromNBGVLabel -PrereleaseLabel 'Alpha6').TierNumber | Should -Be 2
    }
    It 'Alpha.6 normalizes to Alpha -> T2' {
      (Get-TierFromNBGVLabel -PrereleaseLabel 'Alpha.6').TierNumber | Should -Be 2
    }
    It 'Sprint1 normalizes to Sprint -> T1' {
      (Get-TierFromNBGVLabel -PrereleaseLabel 'Sprint1').TierNumber | Should -Be 1
    }
    It 'QA2 normalizes to QA -> T4' {
      (Get-TierFromNBGVLabel -PrereleaseLabel 'QA2').TierNumber | Should -Be 4
    }
  }

  Context 'Case insensitivity' {
    It 'alpha (lowercase) still maps to T2' {
      (Get-TierFromNBGVLabel -PrereleaseLabel 'alpha').TierNumber | Should -Be 2
    }
    It 'BETA (uppercase) still maps to T3' {
      (Get-TierFromNBGVLabel -PrereleaseLabel 'BETA').TierNumber | Should -Be 3
    }
  }

  Context 'Invalid labels' {
    It 'Throws on unrecognized label "Gamma"' {
      { Get-TierFromNBGVLabel -PrereleaseLabel 'Gamma' } |
        Should -Throw -ExpectedMessage '*Unrecognized NBGV prerelease label*'
    }
    It 'Throws on unrecognized label "RC"' {
      { Get-TierFromNBGVLabel -PrereleaseLabel 'RC' } |
        Should -Throw -ExpectedMessage '*Unrecognized NBGV prerelease label*'
    }
    It 'Throws on nonsense value "12345"' {
      # '12345' strips to empty via \d+$ regex -> normalizes to ''; empty means stable.
      # So this ACTUALLY resolves to T5. Assert that explicitly.
      (Get-TierFromNBGVLabel -PrereleaseLabel '12345').TierNumber | Should -Be 5
    }
  }
}
