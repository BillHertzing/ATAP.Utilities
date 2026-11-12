BeforeAll {
  $modulePath = Join-Path $PSScriptRoot '..\..\ATAP.Utilities.SystemParityMonitor.PowerShell.psd1'
  $loaded = @(Get-Module -Name 'ATAP.Utilities.SystemParityMonitor.PowerShell')
  if ($loaded.Count -eq 0) {
    Import-Module -Name $modulePath -Force -ErrorAction Stop
  }
}

Describe 'Get-PackageManagerParitySurfaces NuGet parsing' -Tag 'Unit', 'ParityNuGet' {
  BeforeEach {
    $script:profiles = @(
      [pscustomobject]@{
        Identity = 'ATAP\Developer'
        PipPath = ''
        NpmPrefix = ''
        NuGetToolPath = 'C:\Profiles\Developer\.dotnet\tools'
      }
    )
  }

  It 'ignores first-run banner text before the table and yields exactly 3 tools' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ Profiles = $script:profiles } {
      param($Profiles)
      Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'dotnet' } -MockWith { [pscustomobject]@{ Source = 'dotnet.exe' } }
      Mock -CommandName Get-Command -ParameterFilter { $Name -ne 'dotnet' } -MockWith { $null }
      Mock -CommandName Invoke-ParityNativeCommand -MockWith {
        [pscustomobject]@{
          ExitCode = 0
          Output = @(
            'Welcome to .NET 10.0!',
            '---------------------',
            'SDK Version: 10.0.404',
            '',
            'Telemetry',
            '---------',
            'The .NET tools collect usage data in order to help us improve your experience.',
            '',
            'Package Id      Version      Commands',
            '------------------------------------------',
            'dotnet-ef       10.0.0       dotnet-ef',
            'dotnet-reportgenerator-globaltool   5.1.21   reportgenerator',
            'app             5.1.21       app',
            ''
          )
        }
      }

      $surfaces = @(Get-PackageManagerParitySurfaces -HostName 'utat01' -PackageManagerProfiles $Profiles)
      $tools = @($surfaces | Where-Object { $_.Category -eq 'PackageManager' -and $_.Item -like '*/NuGet/*' })
      $tools | Should -HaveCount 3
      @($tools.Item) | Should -Not -Contain 'ATAP\Developer/NuGet/welcome'
      @($tools.Item) | Should -Not -Contain 'ATAP\Developer/NuGet/sdk'
      @($tools.Item) | Should -Not -Contain 'ATAP\Developer/NuGet/the'
      ($surfaces | Where-Object { $_.Category -eq 'PackageManagerStatus' -and $_.Item -eq 'ATAP\Developer/NuGet' }).Value |
        Should -Be 'Available;PackageCount=3'
    }
  }

  It 'leaves table-only output unchanged' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ Profiles = $script:profiles } {
      param($Profiles)
      Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'dotnet' } -MockWith { [pscustomobject]@{ Source = 'dotnet.exe' } }
      Mock -CommandName Get-Command -ParameterFilter { $Name -ne 'dotnet' } -MockWith { $null }
      Mock -CommandName Invoke-ParityNativeCommand -MockWith {
        [pscustomobject]@{
          ExitCode = 0
          Output = @('Package Id      Version      Commands', '------------------------------------------', 'dotnet-ef       10.0.0       dotnet-ef')
        }
      }

      $surfaces = @(Get-PackageManagerParitySurfaces -HostName 'utat01' -PackageManagerProfiles $Profiles)
      $tool = @($surfaces | Where-Object { $_.Category -eq 'PackageManager' -and $_.Item -like '*/NuGet/*' })
      $tool | Should -HaveCount 1
      $tool[0].Item | Should -Be 'ATAP\Developer/NuGet/dotnet-ef'
      $tool[0].Value | Should -Be '10.0.0'
    }
  }

  It 'yields 0 tools for an empty table and still reports Available' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ Profiles = $script:profiles } {
      param($Profiles)
      Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'dotnet' } -MockWith { [pscustomobject]@{ Source = 'dotnet.exe' } }
      Mock -CommandName Get-Command -ParameterFilter { $Name -ne 'dotnet' } -MockWith { $null }
      Mock -CommandName Invoke-ParityNativeCommand -MockWith {
        [pscustomobject]@{
          ExitCode = 0
          Output = @('Welcome to .NET 10.0!', 'Package Id      Version      Commands', '------------------------------------------')
        }
      }

      $surfaces = @(Get-PackageManagerParitySurfaces -HostName 'utat01' -PackageManagerProfiles $Profiles)
      @($surfaces | Where-Object { $_.Category -eq 'PackageManager' -and $_.Item -like '*/NuGet/*' }) | Should -HaveCount 0
      ($surfaces | Where-Object { $_.Category -eq 'PackageManagerStatus' -and $_.Item -eq 'ATAP\Developer/NuGet' }).Value |
        Should -Be 'Available;PackageCount=0'
    }
  }

  It 'yields 0 tools for banner-only output with no table' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ Profiles = $script:profiles } {
      param($Profiles)
      Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'dotnet' } -MockWith { [pscustomobject]@{ Source = 'dotnet.exe' } }
      Mock -CommandName Get-Command -ParameterFilter { $Name -ne 'dotnet' } -MockWith { $null }
      Mock -CommandName Invoke-ParityNativeCommand -MockWith {
        [pscustomobject]@{ ExitCode = 0; Output = @('Welcome to .NET 10.0!', 'SDK Version: 10.0.404', 'Read more about the new things') }
      }

      $surfaces = @(Get-PackageManagerParitySurfaces -HostName 'utat01' -PackageManagerProfiles $Profiles)
      @($surfaces | Where-Object { $_.Category -eq 'PackageManager' -and $_.Item -like '*/NuGet/*' }) | Should -HaveCount 0
    }
  }

  It 'sets DOTNET_NOLOGO and DOTNET_SKIP_FIRST_TIME_EXPERIENCE for dotnet only and restores prior values' {
    InModuleScope 'ATAP.Utilities.SystemParityMonitor.PowerShell' -Parameters @{ Profiles = $script:profiles } {
      param($Profiles)
      $priorNologo = [Environment]::GetEnvironmentVariable('DOTNET_NOLOGO', 'Process')
      $priorSkip = [Environment]::GetEnvironmentVariable('DOTNET_SKIP_FIRST_TIME_EXPERIENCE', 'Process')
      [Environment]::SetEnvironmentVariable('DOTNET_NOLOGO', 'prior-a', 'Process')
      [Environment]::SetEnvironmentVariable('DOTNET_SKIP_FIRST_TIME_EXPERIENCE', $null, 'Process')
      $script:seen = [System.Collections.Generic.List[object]]::new()
      try {
        Mock -CommandName Get-Command -ParameterFilter { $Name -in @('dotnet', 'choco') } -MockWith { [pscustomobject]@{ Source = "$Name.exe" } }
        Mock -CommandName Get-Command -ParameterFilter { $Name -notin @('dotnet', 'choco') } -MockWith { $null }
        Mock -CommandName Invoke-ParityNativeCommand -MockWith {
          $script:seen.Add([pscustomobject]@{
              Command = $Command
              NoLogo = [Environment]::GetEnvironmentVariable('DOTNET_NOLOGO', 'Process')
              Skip = [Environment]::GetEnvironmentVariable('DOTNET_SKIP_FIRST_TIME_EXPERIENCE', 'Process')
            })
          [pscustomobject]@{ ExitCode = 0; Output = @() }
        }

        $null = Get-PackageManagerParitySurfaces -HostName 'utat01' -PackageManagerProfiles $Profiles

        $dotnetCall = @($script:seen | Where-Object Command -eq 'dotnet.exe')
        $dotnetCall | Should -HaveCount 1
        $dotnetCall[0].NoLogo | Should -Be '1'
        $dotnetCall[0].Skip | Should -Be '1'
        $chocoCall = @($script:seen | Where-Object Command -eq 'choco.exe')
        $chocoCall[0].NoLogo | Should -Be 'prior-a'
        [Environment]::GetEnvironmentVariable('DOTNET_NOLOGO', 'Process') | Should -Be 'prior-a'
        [Environment]::GetEnvironmentVariable('DOTNET_SKIP_FIRST_TIME_EXPERIENCE', 'Process') | Should -BeNullOrEmpty
      } finally {
        [Environment]::SetEnvironmentVariable('DOTNET_NOLOGO', $priorNologo, 'Process')
        [Environment]::SetEnvironmentVariable('DOTNET_SKIP_FIRST_TIME_EXPERIENCE', $priorSkip, 'Process')
      }
    }
  }
}
