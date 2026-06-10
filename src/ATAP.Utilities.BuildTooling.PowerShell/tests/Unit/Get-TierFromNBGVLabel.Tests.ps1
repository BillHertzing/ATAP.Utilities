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
    It 'Empty string maps to T5 Production / powershellget-stable' {
      $r = Get-TierFromNBGVLabel -PrereleaseLabel ''
      $r.TierNumber | Should -Be 5
      $r.TierName   | Should -BeExactly 'Production'
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

  Context 'Feature and unknown labels' {
    It 'Maps a feature label to T1 Experimental' {
      $r = Get-TierFromNBGVLabel -PrereleaseLabel 'PaymentRefactor.17'
      $r.TierNumber | Should -Be 1
      $r.TierName   | Should -BeExactly 'Experimental'
      $r.FeedName   | Should -BeExactly 'powershellget-experimental'
    }

    It 'Maps unknown labels to T1 Experimental' {
      (Get-TierFromNBGVLabel -PrereleaseLabel 'RC').TierNumber | Should -Be 1
    }

    It 'Maps numeric-only nonsense to T1 Experimental rather than Production' {
      (Get-TierFromNBGVLabel -PrereleaseLabel '12345').TierNumber | Should -Be 1
    }
  }
}
