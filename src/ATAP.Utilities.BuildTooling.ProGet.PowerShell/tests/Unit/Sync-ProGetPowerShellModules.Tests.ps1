#Requires -Version 7.0

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $functionPath = Join-Path $moduleRoot 'public\Sync-ProGetPowerShellModules.ps1'

  if (-not (Get-Command -Name Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)]$Rest)
    }
  }
  if (-not (Get-Command -Name Resolve-ProGetFeedFromSettings -ErrorAction SilentlyContinue)) {
    function global:Resolve-ProGetFeedFromSettings { throw 'Test stub must be mocked.' }
  }
  if (-not (Get-Command -Name Install-ATAPModuleAllUsers -ErrorAction SilentlyContinue)) {
    function global:Install-ATAPModuleAllUsers { throw 'Test stub must be mocked.' }
  }

  . $functionPath
}

Describe 'Sync-ProGetPowerShellModules module-loading contract' {
  It 'parses and contains exactly one top-level eponymous function definition' {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
      $functionPath,
      [ref]$tokens,
      [ref]$errors
    )

    @($errors).Count | Should -Be 0
    @($ast.EndBlock.Statements).Count | Should -Be 1
    $ast.EndBlock.Statements[0] | Should -BeOfType ([System.Management.Automation.Language.FunctionDefinitionAst])
    $ast.EndBlock.Statements[0].Name | Should -Be 'Sync-ProGetPowerShellModules'
  }

  It 'contains no host-specific ProGet hostname or top-level script parameter block' {
    $source = Get-Content -LiteralPath $functionPath -Raw
    $source | Should -Not -Match '(?i)utat0[0-9]'

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
      $functionPath,
      [ref]$tokens,
      [ref]$errors
    )
    $ast.ParamBlock | Should -BeNullOrEmpty
  }
}

Describe 'Sync-ProGetPowerShellModules' {
  BeforeEach {
    Mock Resolve-ProGetFeedFromSettings {
      [pscustomobject]@{
        FeedName    = 'powershellget-stable'
        Tier        = 'stable'
        Uri         = 'https://proget.example.test/nuget/powershellget-stable/'
        EndpointUri = 'https://proget.example.test/nuget/powershellget-stable/v3/index.json'
      }
    }
    Mock Get-PSRepository {
      [pscustomobject]@{
        Name           = $Name
        SourceLocation = 'https://proget.example.test/nuget/powershellget-stable/'
      }
    }
    Mock Find-Module {
      [pscustomobject]@{ Name = 'Fixture.Module'; Version = '1.2.0' }
    }
    Mock Get-Module { $null }
    Mock Install-Module { }
    Mock Install-ATAPModuleAllUsers {
      [pscustomobject]@{ ExitStatus = 0; ErrorText = $null }
    }
  }

  It 'resolves the configured tier and installs a missing module' {
    $result = Sync-ProGetPowerShellModules -Tier QA -Scope CurrentUser -Confirm:$false

    $result.Status | Should -Be 'Missing'
    $result.ActionTaken | Should -Be 'Installed'
    $result.Repository | Should -Be 'powershellget-stable'
    $result.Tier | Should -Be 'stable'
    Assert-MockCalled Resolve-ProGetFeedFromSettings -Times 1 -Exactly -Scope It -ParameterFilter {
      $FeedType -eq 'powershellget' -and $Tier -eq 'QA'
    }
    Assert-MockCalled Install-Module -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'Fixture.Module' -and
      [string]$RequiredVersion -eq '1.2.0' -and
      $Repository -eq 'powershellget-stable' -and
      $Scope -eq 'CurrentUser'
    }
  }

  It 'uses an explicit repository and feed from any host without resolving settings' {
    $result = Sync-ProGetPowerShellModules `
      -Repository 'customer-powershell' `
      -FeedUrl 'https://packages.example.test/nuget/customer-powershell/' `
      -Scope CurrentUser `
      -Confirm:$false

    $result.Repository | Should -Be 'customer-powershell'
    $result.Tier | Should -Be 'Explicit'
    $result.FeedUrl | Should -Be 'https://packages.example.test/nuget/customer-powershell/'
    Assert-MockCalled Resolve-ProGetFeedFromSettings -Times 0 -Exactly -Scope It
    Assert-MockCalled Find-Module -Times 1 -Exactly -Scope It -ParameterFilter {
      $Repository -eq 'customer-powershell' -and $Name -eq 'ATAP.*'
    }
  }

  It 'derives FeedUrl from an explicitly registered repository when omitted' {
    Mock Get-PSRepository {
      [pscustomobject]@{
        Name           = 'customer-powershell'
        SourceLocation = 'https://packages.example.test/nuget/customer-powershell/'
      }
    }

    $result = Sync-ProGetPowerShellModules `
      -Repository 'customer-powershell' `
      -Scope CurrentUser `
      -Confirm:$false

    $result.FeedUrl | Should -Be 'https://packages.example.test/nuget/customer-powershell/'
    Assert-MockCalled Resolve-ProGetFeedFromSettings -Times 0 -Exactly -Scope It
  }

  It 'does not install when the newest local version equals the feed version' {
    Mock Get-Module { [pscustomobject]@{ Name = 'Fixture.Module'; Version = [version]'1.2.0' } }

    $result = Sync-ProGetPowerShellModules -Confirm:$false

    $result.Status | Should -Be 'UpToDate'
    $result.ActionTaken | Should -Be 'Skipped'
    Assert-MockCalled Install-Module -Times 0 -Exactly -Scope It
  }

  It 'does not downgrade when the local version is newer' {
    Mock Get-Module { [pscustomobject]@{ Name = 'Fixture.Module'; Version = [version]'2.0.0' } }

    $result = Sync-ProGetPowerShellModules -Confirm:$false

    $result.Status | Should -Be 'UpToDate'
    Assert-MockCalled Install-Module -Times 0 -Exactly -Scope It
  }

  It 'installs an available upgrade' {
    Mock Get-Module { [pscustomobject]@{ Name = 'Fixture.Module'; Version = [version]'1.1.9' } }

    $result = Sync-ProGetPowerShellModules -Scope CurrentUser -Confirm:$false

    $result.Status | Should -Be 'UpgradeAvailable'
    $result.InstalledVersion | Should -Be '1.1.9'
    $result.ActionTaken | Should -Be 'Installed'
  }

  It 'selects the newest semantic prerelease rather than sorting version text' {
    Mock Find-Module {
      [pscustomobject]@{ Name = 'Fixture.Module'; Version = '1.2.0-beta.2' }
      [pscustomobject]@{ Name = 'Fixture.Module'; Version = '1.2.0-beta.10' }
      [pscustomobject]@{ Name = 'Fixture.Module'; Version = '1.2.0-beta.9' }
    }
    Mock Get-Module { [pscustomobject]@{ Name = 'Fixture.Module'; Version = [version]'1.1.0' } }

    $result = Sync-ProGetPowerShellModules -Scope CurrentUser -Confirm:$false

    $result.ProGetVersion | Should -Be '1.2.0-beta.10'
    Assert-MockCalled Install-Module -Times 1 -Exactly -Scope It -ParameterFilter {
      [string]$RequiredVersion -eq '1.2.0-beta.10' -and $AllowPrerelease
    }
  }

  It 'fails clearly instead of sending a prerelease to the validated installer that accepts release versions only' {
    Mock Find-Module {
      [pscustomobject]@{ Name = 'Fixture.Module'; Version = '1.2.0-beta.1' }
    }

    $result = Sync-ProGetPowerShellModules `
      -UseValidatedInstaller `
      -ExpectedSha256ByModule @{ 'Fixture.Module' = ('D' * 64) } `
      -Confirm:$false

    $result.ActionTaken | Should -Be 'Failed'
    $result.ErrorText | Should -Match 'does not support prerelease version'
    Assert-MockCalled Install-ATAPModuleAllUsers -Times 0 -Exactly -Scope It
  }

  It 'honors WhatIf without invoking either installer' {
    $result = Sync-ProGetPowerShellModules -WhatIf

    $result.ActionTaken | Should -Be 'WhatIf'
    Assert-MockCalled Install-Module -Times 0 -Exactly -Scope It
    Assert-MockCalled Install-ATAPModuleAllUsers -Times 0 -Exactly -Scope It
  }

  It 'uses the validated installer with the exact feed URI and hash pin' {
    $hash = 'A' * 64

    $result = Sync-ProGetPowerShellModules `
      -Repository 'customer-powershell' `
      -FeedUrl 'https://packages.example.test/nuget/customer-powershell/' `
      -UseValidatedInstaller `
      -ExpectedSha256ByModule @{ 'Fixture.Module' = $hash } `
      -Confirm:$false

    $result.ActionTaken | Should -Be 'Installed'
    Assert-MockCalled Install-ATAPModuleAllUsers -Times 1 -Exactly -Scope It -ParameterFilter {
      $ModuleName -eq 'Fixture.Module' -and
      [string]$RequiredVersion -eq '1.2.0' -and
      $Repository -eq 'customer-powershell' -and
      $FeedUrl -eq 'https://packages.example.test/nuget/customer-powershell/' -and
      $ExpectedSha256 -eq $hash
    }
    Assert-MockCalled Install-Module -Times 0 -Exactly -Scope It
  }

  It 'fails only the affected module when its validated-installer hash is missing' {
    $result = Sync-ProGetPowerShellModules `
      -UseValidatedInstaller `
      -ExpectedSha256ByModule @{} `
      -Confirm:$false

    $result.ActionTaken | Should -Be 'Failed'
    $result.ErrorText | Should -Match 'valid SHA-256 pin is required'
    Assert-MockCalled Install-ATAPModuleAllUsers -Times 0 -Exactly -Scope It
  }

  It 'reports a validated-installer failure without claiming installation' {
    Mock Install-ATAPModuleAllUsers {
      [pscustomobject]@{ ExitStatus = 1; ErrorText = 'dependency floor not met' }
    }

    $result = Sync-ProGetPowerShellModules `
      -UseValidatedInstaller `
      -ExpectedSha256ByModule @{ 'Fixture.Module' = ('B' * 64) } `
      -Confirm:$false

    $result.ActionTaken | Should -Be 'Failed'
    $result.ErrorText | Should -Match 'dependency floor not met'
  }

  It 'fails closed when feed resolution fails and never invokes an installer' {
    Mock Resolve-ProGetFeedFromSettings { throw 'settings unavailable' }

    { Sync-ProGetPowerShellModules -Confirm:$false } | Should -Throw '*settings unavailable*'
    Assert-MockCalled Install-Module -Times 0 -Exactly -Scope It
    Assert-MockCalled Install-ATAPModuleAllUsers -Times 0 -Exactly -Scope It
  }

  It 'rejects an explicit FeedUrl without an explicit Repository' {
    { Sync-ProGetPowerShellModules -FeedUrl 'https://packages.example.test/feed/' -Confirm:$false } |
      Should -Throw '*Repository must be supplied*'
  }

  It 'rejects CurrentUser scope with the validated AllUsers installer' {
    { Sync-ProGetPowerShellModules -Scope CurrentUser -UseValidatedInstaller -Confirm:$false } |
      Should -Throw '*requires Scope AllUsers*'
  }

  It 'rejects cleartext HTTP for the validated installer' {
    { Sync-ProGetPowerShellModules `
        -Repository 'customer-powershell' `
        -FeedUrl 'http://packages.example.test/nuget/customer-powershell/' `
        -UseValidatedInstaller `
        -ExpectedSha256ByModule @{ 'Fixture.Module' = ('C' * 64) } `
        -Confirm:$false } |
      Should -Throw '*requires FeedUrl to use HTTPS*'
  }

  It 'returns no rows and performs no installation when the feed has no matches' {
    Mock Find-Module { $null }

    $result = @(Sync-ProGetPowerShellModules -Confirm:$false)

    $result.Count | Should -Be 0
    Assert-MockCalled Install-Module -Times 0 -Exactly -Scope It
  }
}
