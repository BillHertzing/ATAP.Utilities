#Requires -Version 7.0

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Register-ProGetFeedSet.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)]$rest)
    }
  }

  foreach ($commandName in @('Get-PSResourceRepository', 'Register-PSResourceRepository', 'Set-PSResourceRepository', 'Unregister-PSResourceRepository', 'Get-PSRepository', 'Register-PSRepository', 'Set-PSRepository')) {
    if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
      $functionPath = "Function:\global:$commandName"
      Set-Item -Path $functionPath -Value { param([Parameter(ValueFromRemainingArguments = $true)]$rest) }
    }
  }
}

Describe 'Register-ProGetFeedSet' -Tag 'Unit' {
  BeforeEach {
    # Minimal ConfigRootKeys + settings carrying a powershellget feed collection.
    $feedCollectionKey = 'ProGetFeedCollection'
    $global:configRootKeys = @{ 'ProGetFeedCollectionConfigRootKey' = $feedCollectionKey }
    $global:settings = @{
      $feedCollectionKey = @{
        'pwshStable' = @{
          FeedName   = 'powershellget-stable'
          FeedType   = 'powershellget'
          Uri         = 'https://utat022:50000/nuget/powershellget-stable/'
          NuGetV3Uri = 'https://utat022:50000/nuget/powershellget-stable/v2'
        }
        'nugetStable' = @{
          FeedName   = 'nuget-stable'
          FeedType   = 'nuget'
          NuGetV3Uri = 'https://utat022:50000/nuget/nuget-stable/v3/index.json'
        }
      }
    }

    Mock Write-PSFMessage { }
    # Live registry starts with one obsolete legacy feed and no canonical feeds.
    Mock Get-PSResourceRepository {
      @(
        [PSCustomObject]@{ Name = 'IntPreNugProdPushFeed'; Uri = 'https://utat022:50000/nuget/IntPreNugProdPushFeed/v3/index.json' }
        [PSCustomObject]@{ Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2' }
      )
    }
    Mock Register-PSResourceRepository { [PSCustomObject]@{ Name = 'powershellget-stable' } }
    Mock Set-PSResourceRepository { [PSCustomObject]@{ Name = 'powershellget-stable' } }
    Mock Unregister-PSResourceRepository { }
    Mock Get-PSRepository { @() }
    Mock Register-PSRepository { }
    Mock Set-PSRepository { }
  }

  AfterEach {
    Remove-Variable -Name settings -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable -Name configRootKeys -Scope Global -ErrorAction SilentlyContinue
  }

  It 'unregisters obsolete legacy promotion-matrix feeds by default' {
    Register-ProGetFeedSet -Confirm:$false | Out-Null

    Assert-MockCalled Unregister-PSResourceRepository -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'IntPreNugProdPushFeed'
    }
  }

  It 'does not unregister canonical or connector repositories' {
    Register-ProGetFeedSet -Confirm:$false | Out-Null

    Assert-MockCalled Unregister-PSResourceRepository -Times 0 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'PSGallery'
    }
  }

  It 'registers only powershellget feeds in both repository stores' {
    Register-ProGetFeedSet -Confirm:$false | Out-Null

    Assert-MockCalled Register-PSResourceRepository -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'powershellget-stable' -and $Uri -eq 'https://utat022:50000/nuget/powershellget-stable/v2'
    }
    Assert-MockCalled Register-PSResourceRepository -Times 0 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'nuget-stable'
    }
    Assert-MockCalled Register-PSRepository -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'powershellget-stable' -and
      $SourceLocation -eq 'https://utat022:50000/nuget/powershellget-stable/' -and
      $PublishLocation -eq 'https://utat022:50000/nuget/powershellget-stable/' -and
      $InstallationPolicy -eq 'Trusted'
    }
  }

  It 'skips pruning when -PruneObsolete is $false' {
    Register-ProGetFeedSet -PruneObsolete $false -Confirm:$false | Out-Null

    Assert-MockCalled Unregister-PSResourceRepository -Times 0 -Exactly -Scope It
  }

  It 'is idempotent — an already-registered canonical feed is not re-registered' {
    Mock Get-PSResourceRepository {
      @( [PSCustomObject]@{ Name = 'powershellget-stable'; Uri = 'https://utat022:50000/nuget/powershellget-stable/v2'; Trusted = $true } )
    }

    $result = Register-ProGetFeedSet -Confirm:$false

    Assert-MockCalled Register-PSResourceRepository -Times 0 -Exactly -Scope It
    Assert-MockCalled Set-PSResourceRepository -Times 0 -Exactly -Scope It
    ($result | Where-Object { $_.RepositoryKind -eq 'PSResourceGet' }).RegistrationResult | Should -Be 'AlreadyRegistered'
  }

  It 'reconciles an existing repository whose URI or trust policy has drifted' {
    Mock Get-PSResourceRepository {
      @( [PSCustomObject]@{ Name = 'powershellget-stable'; Uri = 'http://legacy:50000/nuget/powershellget-stable/v2'; Trusted = $false } )
    }

    $result = Register-ProGetFeedSet -Confirm:$false

    Assert-MockCalled Register-PSResourceRepository -Times 0 -Exactly -Scope It
    Assert-MockCalled Set-PSResourceRepository -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'powershellget-stable' -and
      $Uri -eq 'https://utat022:50000/nuget/powershellget-stable/v2' -and
      $Trusted
    }
    ($result | Where-Object { $_.RepositoryKind -eq 'PSResourceGet' }).RegistrationResult | Should -Be 'Updated'
  }

  It 'reconciles URI and trust drift in the PowerShellGet repository store' {
    Mock Get-PSRepository {
      @( [PSCustomObject]@{
          Name = 'powershellget-stable'
          SourceLocation = 'http://legacy:50000/nuget/powershellget-stable/'
          PublishLocation = 'http://legacy:50000/nuget/powershellget-stable/'
          InstallationPolicy = 'Untrusted'
        } )
    }

    $result = Register-ProGetFeedSet -Confirm:$false

    Assert-MockCalled Register-PSRepository -Times 0 -Exactly -Scope It
    Assert-MockCalled Set-PSRepository -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'powershellget-stable' -and
      $SourceLocation -eq 'https://utat022:50000/nuget/powershellget-stable/' -and
      $PublishLocation -eq 'https://utat022:50000/nuget/powershellget-stable/' -and
      $InstallationPolicy -eq 'Trusted'
    }
    ($result | Where-Object { $_.RepositoryKind -eq 'PowerShellGet' }).RegistrationResult | Should -Be 'Updated'
  }
}
