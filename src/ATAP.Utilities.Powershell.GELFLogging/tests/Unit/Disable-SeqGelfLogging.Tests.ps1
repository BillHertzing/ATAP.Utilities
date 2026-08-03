BeforeAll {
  $script:moduleRoot = (Resolve-Path "$PSScriptRoot\..\..").Path

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)] $Rest) }
  }

  . "$script:moduleRoot\public\Disable-SeqGelfLogging.ps1"
  . "$script:moduleRoot\public\Get-SeqGelfLoggingStatus.ps1"
}

AfterAll {
  Remove-Item Function:\Write-PSFMessage -Force -ErrorAction SilentlyContinue
}

Describe 'Disable-SeqGelfLogging [public]' -Tag 'Unit' {

  Context 'when the provider was never registered' {
    BeforeEach {
      # Profile teardown and cleanup scripts cannot know whether anything was ever enabled;
      # this must report, not throw.
      Mock -CommandName Get-PSFLoggingProvider -MockWith { $null }
    }

    It 'reports rather than throwing' {
      { Disable-SeqGelfLogging -Confirm:$false } | Should -Not -Throw
    }

    It 'returns WasEnabled false and explains why' {
      $result = Disable-SeqGelfLogging -Confirm:$false
      $result.WasEnabled | Should -BeFalse
      $result.Enabled | Should -BeFalse
      $result.Notes | Should -BeLike '*not registered*'
    }

    It 'never calls Set-PSFLoggingProvider' {
      Mock -CommandName Set-PSFLoggingProvider -MockWith { }
      $null = Disable-SeqGelfLogging -Confirm:$false
      Should -Invoke -CommandName Set-PSFLoggingProvider -Times 0 -Exactly
    }
  }

  Context 'when the instance exists but is already disabled' {
    BeforeEach {
      Mock -CommandName Get-PSFLoggingProvider -MockWith { [pscustomobject]@{ Name = 'gelfudp' } }
      Mock -CommandName Get-PSFLoggingProviderInstance -MockWith { [pscustomobject]@{ Name = 'SendToSEQ'; Enabled = $false } }
      Mock -CommandName Set-PSFLoggingProvider -MockWith { }
      Mock -CommandName Wait-PSFMessage -MockWith { }
    }

    It 'is an idempotent no-op' {
      $result = Disable-SeqGelfLogging -Confirm:$false
      $result.WasEnabled | Should -BeFalse
      Should -Invoke -CommandName Set-PSFLoggingProvider -Times 0 -Exactly
    }
  }

  Context 'when the instance is enabled' {
    BeforeEach {
      Mock -CommandName Get-PSFLoggingProvider -MockWith { [pscustomobject]@{ Name = 'gelfudp' } }
      $script:enabled = $true
      Mock -CommandName Get-PSFLoggingProviderInstance -MockWith {
        [pscustomobject]@{ Name = 'SendToSEQ'; Enabled = $script:enabled }
      }
      Mock -CommandName Set-PSFLoggingProvider -MockWith { $script:enabled = $false }
      Mock -CommandName Wait-PSFMessage -MockWith { }
    }

    It 'disables the instance and reports the transition' {
      $result = Disable-SeqGelfLogging -Confirm:$false
      $result.WasEnabled | Should -BeTrue
      $result.Enabled | Should -BeFalse
      Should -Invoke -CommandName Set-PSFLoggingProvider -Times 1 -Exactly
    }

    It 'flushes BEFORE disabling by default' {
      # PSFramework's logging runspace is async: anything still queued when the instance
      # stops is dropped without a diagnostic.
      $result = Disable-SeqGelfLogging -Confirm:$false
      $result.Flushed | Should -BeTrue
      Should -Invoke -CommandName Wait-PSFMessage -Times 1 -Exactly
    }

    It 'skips the flush and says so when -Flush:$false' {
      $result = Disable-SeqGelfLogging -Flush:$false -Confirm:$false
      $result.Flushed | Should -BeFalse
      Should -Invoke -CommandName Wait-PSFMessage -Times 0 -Exactly
      $result.Notes | Should -BeLike '*discarded*'
    }

    It 'honours -WhatIf without changing state' {
      $null = Disable-SeqGelfLogging -WhatIf
      Should -Invoke -CommandName Set-PSFLoggingProvider -Times 0 -Exactly
    }

    It 'targets the requested instance name' {
      $null = Disable-SeqGelfLogging -InstanceName 'SendToOther' -Confirm:$false
      Should -Invoke -CommandName Set-PSFLoggingProvider -Times 1 -Exactly -ParameterFilter {
        $InstanceName -eq 'SendToOther' -and $Enabled -eq $false
      }
    }

    It 'warns when PSFramework still reports the instance enabled afterwards' {
      Mock -CommandName Set-PSFLoggingProvider -MockWith { }  # refuses to take effect
      $result = Disable-SeqGelfLogging -Confirm:$false
      $result.Enabled | Should -BeTrue
      $result.Notes | Should -BeLike '*still reports*'
    }
  }
}
