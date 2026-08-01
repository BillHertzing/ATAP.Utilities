#Requires -Version 7.0

BeforeAll {
  $publicDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'public'
  . (Join-Path $publicDir 'Register-ProGetFeedSet.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param([Parameter(ValueFromRemainingArguments = $true)]$rest)
    }
  }

  foreach ($commandName in @('Get-PSResourceRepository', 'Register-PSResourceRepository', 'Unregister-PSResourceRepository')) {
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
          NuGetV3Uri = 'http://localhost:50000/nuget/powershellget-stable/v2'
        }
        'nugetStable' = @{
          FeedName   = 'nuget-stable'
          FeedType   = 'nuget'
          NuGetV3Uri = 'http://localhost:50000/nuget/nuget-stable/v3/index.json'
        }
      }
    }

    Mock Write-PSFMessage { }
    # Live registry starts with one obsolete legacy feed and no canonical feeds.
    Mock Get-PSResourceRepository {
      @(
        [PSCustomObject]@{ Name = 'IntPreNugProdPushFeed'; Uri = 'http://localhost:50000/nuget/IntPreNugProdPushFeed/v3/index.json' }
        [PSCustomObject]@{ Name = 'PSGallery'; Uri = 'https://www.powershellgallery.com/api/v2' }
      )
    }
    Mock Register-PSResourceRepository { [PSCustomObject]@{ Name = 'powershellget-stable' } }
    Mock Unregister-PSResourceRepository { }
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

  It 'registers only powershellget feeds using the canonical name and v2 endpoint' {
    Register-ProGetFeedSet -Confirm:$false | Out-Null

    Assert-MockCalled Register-PSResourceRepository -Times 1 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'powershellget-stable' -and $Uri -eq 'http://localhost:50000/nuget/powershellget-stable/v2'
    }
    Assert-MockCalled Register-PSResourceRepository -Times 0 -Exactly -Scope It -ParameterFilter {
      $Name -eq 'nuget-stable'
    }
  }

  It 'skips pruning when -PruneObsolete is $false' {
    Register-ProGetFeedSet -PruneObsolete $false -Confirm:$false | Out-Null

    Assert-MockCalled Unregister-PSResourceRepository -Times 0 -Exactly -Scope It
  }

  It 'is idempotent — an already-registered canonical feed is not re-registered' {
    Mock Get-PSResourceRepository {
      @( [PSCustomObject]@{ Name = 'powershellget-stable'; Uri = 'http://localhost:50000/nuget/powershellget-stable/v2' } )
    }

    $result = Register-ProGetFeedSet -Confirm:$false

    Assert-MockCalled Register-PSResourceRepository -Times 0 -Exactly -Scope It
    ($result | Where-Object { $_.FeedName -eq 'powershellget-stable' }).RegistrationResult | Should -Be 'AlreadyRegistered'
  }
}
