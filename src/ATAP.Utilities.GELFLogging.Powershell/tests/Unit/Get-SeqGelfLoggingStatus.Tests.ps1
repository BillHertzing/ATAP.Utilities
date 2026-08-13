BeforeAll {
  $script:moduleRoot = (Resolve-Path "$PSScriptRoot\..\..").Path

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)] $Rest) }
  }

  . "$script:moduleRoot\public\Get-SeqGelfLoggingStatus.ps1"
}

AfterAll {
  Remove-Item Function:\Write-PSFMessage -Force -ErrorAction SilentlyContinue
}

Describe 'Get-SeqGelfLoggingStatus [public]' -Tag 'Unit' {

  Context 'on a host where nothing was ever enabled' {
    BeforeEach {
      Mock -CommandName Get-PSFLoggingProvider -MockWith { $null }
      Mock -CommandName Get-PSFLoggingProviderInstance -MockWith { $null }
      Mock -CommandName Get-PSFConfigValue -MockWith { $null }
    }

    It 'reports not-registered instead of throwing' {
      $status = Get-SeqGelfLoggingStatus
      $status.Registered | Should -BeFalse
      $status.Enabled | Should -BeFalse
      $status.Endpoint | Should -BeNullOrEmpty
    }

    It 'does not probe for an instance when the provider is absent' {
      $null = Get-SeqGelfLoggingStatus
      Should -Invoke -CommandName Get-PSFLoggingProviderInstance -Times 0 -Exactly
    }
  }

  Context 'when the instance is enabled' {
    BeforeEach {
      Mock -CommandName Get-PSFLoggingProvider -MockWith { [pscustomobject]@{ Name = 'gelfudp' } }
      Mock -CommandName Get-PSFLoggingProviderInstance -MockWith { [pscustomobject]@{ Name = 'SendToSEQ'; Enabled = $true } }
      Mock -CommandName Get-PSFConfigValue -MockWith {
        if ($FullName -like '*GelfServer') { 'utat022' } elseif ($FullName -like '*Port') { 12201 } else { $null }
      }
    }

    It 'reports the endpoint it is shipping to' {
      $status = Get-SeqGelfLoggingStatus
      $status.Registered | Should -BeTrue
      $status.InstanceExists | Should -BeTrue
      $status.Enabled | Should -BeTrue
      $status.Endpoint | Should -Be 'udp://utat022:12201'
    }

    It 'is read-only: never registers the provider or imports the transport' {
      Mock -CommandName Register-PSFLoggingProvider -MockWith { }
      Mock -CommandName Import-Module -MockWith { }
      $null = Get-SeqGelfLoggingStatus
      Should -Invoke -CommandName Register-PSFLoggingProvider -Times 0 -Exactly
      Should -Invoke -CommandName Import-Module -Times 0 -Exactly
    }
  }

  Context 'when configuration is incomplete' {
    BeforeEach {
      Mock -CommandName Get-PSFLoggingProvider -MockWith { [pscustomobject]@{ Name = 'gelfudp' } }
      Mock -CommandName Get-PSFLoggingProviderInstance -MockWith { [pscustomobject]@{ Name = 'SendToSEQ'; Enabled = $true } }
      Mock -CommandName Get-PSFConfigValue -MockWith { $null }
    }

    It 'downgrades to a null endpoint rather than throwing out of a status query' {
      $status = Get-SeqGelfLoggingStatus
      $status.Enabled | Should -BeTrue
      $status.Endpoint | Should -BeNullOrEmpty
    }
  }
}
