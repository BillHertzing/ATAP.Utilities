#Requires -Version 7.0

BeforeAll {
  $privateDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'private'
  . (Join-Path $privateDir 'Import-ATAPModuleFromProGet.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)]$rest)
    }
  }

  if (-not (Get-Command Resolve-ProGetFeedFromSettings -ErrorAction SilentlyContinue)) {
    function global:Resolve-ProGetFeedFromSettings {
      param(
        [string]$FeedType,
        [string]$Tier
      )

      [PSCustomObject]@{
        FeedName = 'powershellget-stable'
        Uri      = 'https://utat022:50000/nuget/powershellget-stable/'
      }
    }
  }

  foreach ($commandName in @('Find-Module', 'Install-Module', 'Get-PSRepository', 'Register-PSRepository', 'Set-PSRepository')) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
      $functionPath = "Function:\global:$commandName"
      Set-Item -Path $functionPath -Value { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }
  }
}

Describe 'Import-ATAPModuleFromProGet [private]' -Tag 'Unit', 'PromotedModuleHostSensitive' {
  BeforeEach {
    $script:requiredCommandAvailable = $false
    $script:installedVersion = $null
    $script:remoteVersion = [version]'0.2.0'

    Mock Write-PSFMessage { }
    Mock Get-PSRepository {
      [PSCustomObject]@{
        Name               = 'powershellget-stable'
        InstallationPolicy = 'Trusted'
      }
    }
    Mock Register-PSRepository { }
    Mock Set-PSRepository { }
    Mock Find-Module {
      [PSCustomObject]@{
        Version = $script:remoteVersion
      }
    }
    Mock Install-Module {
      $script:installedVersion = $script:remoteVersion
    }
    Mock Import-Module {
      $script:requiredCommandAvailable = $true
    } -ParameterFilter { $Name -eq 'ATAP.Utilities.Security.Powershell' }
    Mock Get-Module {
      if ($null -ne $script:installedVersion) {
        [PSCustomObject]@{
          Name       = 'ATAP.Utilities.Security.Powershell'
          Version    = [version]$script:installedVersion
          ModuleBase = 'C:\fake\ATAP.Utilities.Security.Powershell'
        }
      }
    } -ParameterFilter { $Name -eq 'ATAP.Utilities.Security.Powershell' -and $ListAvailable }
    Mock Get-Command {
      if ($script:requiredCommandAvailable) {
        [PSCustomObject]@{
          Name        = 'Get-BitWardenCredential'
          CommandType = 'Function'
        }
      }
    } -ParameterFilter { $Name -eq 'Get-BitWardenCredential' }
  }

  It 'installs the latest stable module when no local copy exists' {
    Import-ATAPModuleFromProGet -ModuleName 'ATAP.Utilities.Security.Powershell' -RequiredCommand 'Get-BitWardenCredential'

    Assert-MockCalled Find-Module -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'ATAP.Utilities.Security.Powershell' -and $Repository -eq 'powershellget-stable'
    }
    Assert-MockCalled Install-Module -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'ATAP.Utilities.Security.Powershell' -and $Repository -eq 'powershellget-stable' -and $Scope -eq 'CurrentUser'
    }
    Assert-MockCalled Import-Module -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'ATAP.Utilities.Security.Powershell' -and $MinimumVersion -eq [version]'0.2.0'
    }
  }

  It 'updates the local copy when ProGet has a newer stable version' {
    $script:installedVersion = [version]'0.1.0'

    Import-ATAPModuleFromProGet -ModuleName 'ATAP.Utilities.Security.Powershell' -RequiredCommand 'Get-BitWardenCredential'

    Assert-MockCalled Install-Module -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'ATAP.Utilities.Security.Powershell'
    }
    Assert-MockCalled Import-Module -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'ATAP.Utilities.Security.Powershell' -and $MinimumVersion -eq [version]'0.2.0'
    }
  }

  It 'falls back to the installed module when ProGet lookup fails' {
    $script:installedVersion = [version]'0.1.5'
    Mock Find-Module { throw 'repository unavailable' }

    Import-ATAPModuleFromProGet -ModuleName 'ATAP.Utilities.Security.Powershell' -RequiredCommand 'Get-BitWardenCredential'

    Assert-MockCalled Install-Module -Times 0 -Exactly -Scope It
    Assert-MockCalled Import-Module -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'ATAP.Utilities.Security.Powershell' -and $MinimumVersion -eq [version]'0.1.5'
    }
  }

  It 'registers the stable repository when it is missing' {
    Mock Get-PSRepository { $null }

    Import-ATAPModuleFromProGet -ModuleName 'ATAP.Utilities.Security.Powershell' -RequiredCommand 'Get-BitWardenCredential'

    Assert-MockCalled Register-PSRepository -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'powershellget-stable' -and $SourceLocation -eq 'https://utat022:50000/nuget/powershellget-stable/'
    }
  }
}
