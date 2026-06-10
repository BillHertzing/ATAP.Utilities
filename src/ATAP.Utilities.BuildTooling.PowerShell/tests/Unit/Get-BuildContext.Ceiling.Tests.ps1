#Requires -Version 7.0

BeforeAll {
  $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $script:publicDir = Join-Path $script:moduleRoot 'public'
  $script:privateDir = Join-Path $script:moduleRoot 'private'

  . (Join-Path $script:publicDir 'Resolve-FeatureSlug.ps1')
  . (Join-Path $script:privateDir 'Get-CeilingFromPrereleaseLabel.ps1')
  . (Join-Path $script:privateDir 'Get-CurrentTierFromStage.ps1')
  . (Join-Path $script:publicDir 'Get-BuildContext.ps1')

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage {
      param(
        [string]$FunctionName,
        [string]$ModuleName,
        [string]$Level,
        [string]$Message,
        [string[]]$Tag
      )
    }
  }

  if (-not (Get-Command 'git' -CommandType Function -ErrorAction SilentlyContinue)) {
    function global:git { }
  }
  if (-not (Get-Command 'nbgv' -CommandType Function -ErrorAction SilentlyContinue)) {
    function global:nbgv { }
  }

  $script:fakeRepoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('GetBuildContextCeiling_' + [Guid]::NewGuid().ToString('N'))
  $script:fakeProjectPath = Join-Path $script:fakeRepoRoot 'src/FakeProject'
  New-Item -ItemType Directory -Path $script:fakeProjectPath -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $script:fakeProjectPath 'version.json') -Value '{"version":"0.1-Sprint.{height}"}' -NoNewline
}

AfterAll {
  if ($script:fakeRepoRoot -and (Test-Path -LiteralPath $script:fakeRepoRoot)) {
    Remove-Item -LiteralPath $script:fakeRepoRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe 'Get-BuildContext ceiling/current-tier split' -Tag 'Unit' {
  BeforeEach {
    $script:GetBuildContextTierAliasWarningEmitted = $false
    $env:INEDOSTAGE_NAME = $null
    $env:BUILDMASTER_STAGE_NAME = $null

    Mock git {
      $global:LASTEXITCODE = 0
      switch -Regex ($args -join ' ') {
        'rev-parse --show-toplevel' { return $script:fakeRepoRoot }
        'symbolic-ref --short HEAD' { return 'main' }
        'rev-parse HEAD'            { return 'abcdef0123456789abcdef0123456789abcdef01' }
        default                     { return '' }
      }
    }
    Mock nbgv {
      $global:LASTEXITCODE = 0
      return '0.1.0-Sprint.42'
    }
    Mock Get-Command -ParameterFilter { $Name -eq 'nbgv' } -MockWith { [PSCustomObject]@{ Name = 'nbgv' } }
  }

  AfterEach {
    $env:INEDOSTAGE_NAME = $null
    $env:BUILDMASTER_STAGE_NAME = $null
  }

  Context 'CeilingTier mapping' {
    $ceilingCases = @(
      @{ Version = '0.1.0-Sprint.42';         Expected = 'Experimental' }
      @{ Version = '0.1.0-PaymentRefactor.7'; Expected = 'Experimental' }
      @{ Version = '0.1.0-Alpha.5';           Expected = 'Development' }
      @{ Version = '0.1.0-Beta.3';            Expected = 'Integration' }
      @{ Version = '0.1.0-QA.1';              Expected = 'QA' }
      @{ Version = '1.0.0';                   Expected = 'Production' }
    )

    It "Maps version '<Version>' to CeilingTier '<Expected>'" -TestCases $ceilingCases {
      param($Version, $Expected)
      Mock nbgv { $global:LASTEXITCODE = 0; return $Version }
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main' -Stage 'Experimental'
      $ctx.CeilingTier | Should -Be $Expected
    }
  }

  Context 'CurrentTier mapping' {
    $stageCases = @(
      @{ Stage = ' Experimental '; Expected = 'Experimental' }
      @{ Stage = 'development';    Expected = 'Development' }
      @{ Stage = 'INTEGRATION';    Expected = 'Integration' }
      @{ Stage = 'qa';             Expected = 'QA' }
      @{ Stage = 'Production';     Expected = 'Production' }
      @{ Stage = 'Stable';         Expected = 'Production' }
    )

    It "Maps stage '<Stage>' to CurrentTier '<Expected>'" -TestCases $stageCases {
      param($Stage, $Expected)
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main' -Stage $Stage
      $ctx.CurrentTier | Should -Be $Expected
    }

    It 'Throws clearly for unknown stage names' {
      { Get-CurrentTierFromStage -Stage 'Canary' } | Should -Throw -ExpectedMessage '*Unknown BuildMaster stage*'
    }
  }

  Context 'Stage fallback' {
    It 'Uses INEDOSTAGE_NAME when -Stage is omitted' {
      $env:INEDOSTAGE_NAME = 'QA'
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main'
      $ctx.CurrentTier | Should -Be 'QA'
    }

    It 'Uses BUILDMASTER_STAGE_NAME when INEDOSTAGE_NAME is absent' {
      $env:BUILDMASTER_STAGE_NAME = 'Integration'
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main'
      $ctx.CurrentTier | Should -Be 'Integration'
    }

    It 'Defaults to Experimental when no stage source exists' {
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main'
      $ctx.CurrentTier | Should -Be 'Experimental'
    }
  }

  Context 'IsAtCeiling' {
    $truthCases = @(
      @{ Version = '0.1.0-Sprint.42'; Stage = 'Experimental'; Expected = $true  }
      @{ Version = '0.1.0-Alpha.5';   Stage = 'Experimental'; Expected = $false }
      @{ Version = '0.1.0-Alpha.5';   Stage = 'Development';  Expected = $true  }
      @{ Version = '0.1.0-Beta.3';    Stage = 'Development';  Expected = $false }
      @{ Version = '0.1.0-Beta.3';    Stage = 'Integration';  Expected = $true  }
      @{ Version = '0.1.0-QA.1';      Stage = 'QA';           Expected = $true  }
      @{ Version = '1.0.0';           Stage = 'Production';   Expected = $true  }
    )

    It "Computes IsAtCeiling for version '<Version>' at stage '<Stage>'" -TestCases $truthCases {
      param($Version, $Stage, $Expected)
      Mock nbgv { $global:LASTEXITCODE = 0; return $Version }
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main' -Stage $Stage
      $ctx.IsAtCeiling | Should -Be $Expected
    }
  }

  Context 'Legacy Tier alias' {
    It 'Aliases CeilingTier and emits one deprecation warning per session' {
      $script:warningCount = 0
      Mock Write-PSFMessage {
        if ($Level -eq 'Warning') {
          $script:warningCount++
        }
      }

      Mock nbgv { $global:LASTEXITCODE = 0; return '0.1.0-Beta.3' }
      $ctx = Get-BuildContext -Application 'ATAP.Utilities' -ProjectPath $script:fakeProjectPath -Branch 'main' -Stage 'Development'

      $ctx.Tier | Should -Be 'Integration'
      $ctx.Tier | Should -Be 'Integration'
      $script:warningCount | Should -Be 1
    }
  }
}
