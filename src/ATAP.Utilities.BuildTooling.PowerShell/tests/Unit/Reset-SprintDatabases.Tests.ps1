BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  function Build-DatabaseWithFlyway {
    param(
      [string]$DatabaseName,
      [string]$Environment,
      [string]$DatabaseHost,
      [string]$SqlInstance,
      [string]$ConnectionMethod,
      [string]$FlywayBasePath,
      [string]$FlywayTomlPath,
      [string]$FlywaySqlMigrationsPath,
      [string]$RepositoryRoot,
      [switch]$IntegratedSecurity,
      [switch]$Force
    )
    [PSCustomObject]@{ Success = $true; Errors = @() }
  }

  function Install-SqlServerInstance { throw 'Reset-SprintDatabases must not create SQL Server instances.' }
  function Remove-DbaDatabase { throw 'Reset-SprintDatabases delegates database reset to Build-DatabaseWithFlyway.' }

  . "$PSScriptRoot\..\..\public\Reset-SprintDatabases.ps1"

  $script:tempRepoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('rsd-test-' + [guid]::NewGuid().ToString('N'))
  $script:flywayBase = Join-Path $script:tempRepoRoot 'Database' 'Flyway'
  New-Item -ItemType Directory -Path (Join-Path $script:flywayBase 'SQL') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $script:flywayBase 'flyway.toml') -Value '# stub' -Encoding UTF8
}

AfterAll {
  Remove-Item -LiteralPath $script:tempRepoRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Reset-SprintDatabases [public]' {
  BeforeEach {
    Mock -CommandName Get-Service -MockWith {
      [PSCustomObject]@{ Name = $Name; Status = 'Running' }
    } -ParameterFilter { $Name -like 'MSSQL$*' }

    Mock -CommandName Build-DatabaseWithFlyway -MockWith {
      [PSCustomObject]@{ Success = $true; Errors = @() }
    }
    Mock -CommandName Install-SqlServerInstance -MockWith { throw 'Must not be called.' }
    Mock -CommandName Remove-DbaDatabase -MockWith { throw 'Must not be called.' }
  }

  It 'function exists and is loaded' {
    Get-Command -Name 'Reset-SprintDatabases' -CommandType Function |
      Should -Not -BeNullOrEmpty
  }

  It 'calls Build-DatabaseWithFlyway once per instance and database with Force' {
    $results = Reset-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities', 'AceCommander') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -Confirm:$false

    $results.Count | Should -Be 4
    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 4 -Exactly -ParameterFilter { $Force }
    Should -Invoke -CommandName Install-SqlServerInstance -Times 0 -Exactly
    Should -Invoke -CommandName Remove-DbaDatabase -Times 0 -Exactly
  }

  It 'passes the expected environment and SQL instance to Flyway builds' {
    Reset-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -Confirm:$false | Out-Null

    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 1 -ParameterFilter {
      $SqlInstance -eq 'Devtester' -and $Environment -eq 'Development'
    }
    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 1 -ParameterFilter {
      $SqlInstance -eq 'Exptester' -and $Environment -eq 'Experimental'
    }
  }

  It 'fails with onboarding remediation and does not reset anything when an instance is missing' {
    Mock -CommandName Get-Service -MockWith {
      if ($Name -eq 'MSSQL$Devtester') {
        [PSCustomObject]@{ Name = $Name; Status = 'Running' }
      }
    } -ParameterFilter { $Name -like 'MSSQL$*' }

    {
      Reset-SprintDatabases `
        -InstanceNames @('Devtester', 'Exptester') `
        -Databases @('ATAPUtilities') `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot `
        -Confirm:$false
    } | Should -Throw -ExpectedMessage '*developer onboarding SQL Server instance setup*'

    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 0 -Exactly
  }

  It 'does not call Build-DatabaseWithFlyway when WhatIf is set' {
    $results = Reset-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities', 'AceCommander') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -WhatIf

    $results.Count | Should -Be 4
    ($results | Where-Object { -not $_.skipped }).Count | Should -Be 0
    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 0 -Exactly
  }

  It 'does not call Build-DatabaseWithFlyway when DryRun is set' {
    $results = Reset-SprintDatabases `
      -InstanceNames @('Devtester') `
      -Databases @('ATAPUtilities', 'AceCommander') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -DryRun

    $results.Count | Should -Be 2
    ($results | Where-Object { -not $_.dryRun -or -not $_.skipped -or $_.reset }).Count | Should -Be 0
    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 0 -Exactly
  }

  It 'uses Dev and Exp instance names for the current user by default' {
    Reset-SprintDatabases `
      -Databases @('ATAPUtilities') `
      -FlywayBasePath $script:flywayBase `
      -RepositoryRoot $script:tempRepoRoot `
      -DryRun | Out-Null

    Should -Invoke -CommandName Get-Service -Times 1 -ParameterFilter { $Name -eq "MSSQL`$Dev$($env:USERNAME)" }
    Should -Invoke -CommandName Get-Service -Times 1 -ParameterFilter { $Name -eq "MSSQL`$Exp$($env:USERNAME)" }
  }
}
