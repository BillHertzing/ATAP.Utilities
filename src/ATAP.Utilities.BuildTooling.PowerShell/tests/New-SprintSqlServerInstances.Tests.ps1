# AI assisted using ./claude/Rules/Powershell.md as guidelines
# Pester 5+ happy-path tests for New-SprintSqlServerInstances

BeforeAll {
  $functionName = 'New-SprintSqlServerInstances'
  if (-not (Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
    $functionPath = Join-Path $PSScriptRoot -ChildPath "../public/$functionName.ps1"
    if (Test-Path $functionPath) {
      . $functionPath
    } else {
      throw "Function file not found: $functionPath"
    }
  }

  # Minimal stub for Install-SqlServerInstance — returns a success object
  function script:Install-SqlServerInstance {
    param([string]$SQLInstance, [string]$DatabaseHost, [string]$ConnectionMethod, [switch]$Confirm)
    [PSCustomObject]@{ Success = $true; Cancelled = $false }
  }

  # Minimal stub for Build-DatabaseWithFlyway — returns success
  function script:Build-DatabaseWithFlyway {
    param(
      [string]$DatabaseName,
      [string]$Environment,
      [string]$DatabaseHost,
      [string]$SqlInstance,
      [string]$ConnectionMethod,
      [string]$FlywayBasePath,
      [string]$FlywayTomlPath,
      [string]$FlywaySqlMigrationsPath,
      [switch]$IntegratedSecurity,
      [switch]$Force
    )
    [PSCustomObject]@{ Success = $true; Errors = @() }
  }

  # Create a temporary directory that acts as a fake repository root with a
  # flyway.toml so the function's path checks do not throw.
  $script:tempRepoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('nssi-test-' + [guid]::NewGuid().ToString('N'))
  $script:flywayBase = Join-Path $script:tempRepoRoot 'Database' 'Flyway'
  $script:flywaySQL = Join-Path $script:flywayBase 'SQL'

  New-Item -ItemType Directory -Path $script:flywaySQL -Force | Out-Null
  Set-Content -Path (Join-Path $script:flywayBase 'flyway.toml') -Value '# stub' -Encoding UTF8

  # Create stub helper scripts so the function's dot-source guards pass if
  # Install-SqlServerInstance / Invoke-Flyway are somehow not loaded yet.
  $dmPub = Join-Path $script:tempRepoRoot 'src' 'ATAP.Utilities.DatabaseManagement.Powershell' 'public'
  New-Item -ItemType Directory -Path $dmPub -Force | Out-Null

  Set-Content -Path (Join-Path $dmPub 'Install-SqlServerInstance.ps1') `
    -Value "function Install-SqlServerInstance { param([string]`$SQLInstance,[string]`$DatabaseHost,[string]`$ConnectionMethod,[switch]`$Confirm) ; [PSCustomObject]@{Success=`$true;Cancelled=`$false} }" `
    -Encoding UTF8

  Set-Content -Path (Join-Path $dmPub 'Build-DatabaseWithFlyway.ps1') `
    -Value @'
function Build-DatabaseWithFlyway {
    param(
        [string]$DatabaseName, [string]$Environment, [string]$DatabaseHost,
        [string]$SqlInstance, [string]$ConnectionMethod,
        [string]$FlywayBasePath,
        [string]$FlywayTomlPath, [string]$FlywaySqlMigrationsPath,
        [switch]$IntegratedSecurity, [switch]$Force
    )
    [PSCustomObject]@{ Success = $true; Errors = @() }
}
'@ -Encoding UTF8
}

AfterAll {
  if (Test-Path $script:tempRepoRoot) {
    Remove-Item -Recurse -Force $script:tempRepoRoot -ErrorAction SilentlyContinue
  }
}

Describe 'New-SprintSqlServerInstances — happy path' {

  It 'function exists and is loaded' {
    Get-Command -Name 'New-SprintSqlServerInstances' -CommandType Function |
      Should -Not -BeNullOrEmpty
  }

  Context 'when both instances do not yet exist (new sprint)' {

    BeforeEach {
      # Mock Get-Service to report that neither instance service exists
      Mock -CommandName 'Get-Service' -MockWith { $null } -ParameterFilter {
        $Name -like 'MSSQL$*'
      }

      # Track Install-SqlServerInstance and Build-DatabaseWithFlyway calls
      Mock -CommandName 'Install-SqlServerInstance' -MockWith { [PSCustomObject]@{ Success = $true; Cancelled = $false } }
      Mock -CommandName 'Build-DatabaseWithFlyway' -MockWith { [PSCustomObject]@{ Success = $true; Errors = @() } }
      # Databases do not yet exist — idempotency check returns nothing
      Mock -CommandName 'Get-DbaDatabase' -MockWith { $null }
    }

    It 'returns one result row per (instance × database) combination' {
      $results = New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      # 2 instances × 2 databases = 4 rows
      $results.Count | Should -Be 4
    }

    It 'all result rows have instanceReady = $true and baselined = $true' {
      $results = New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      foreach ($row in $results) {
        $row.instanceReady | Should -BeTrue -Because "instance $($row.instanceName) should be ready"
        $row.built | Should -BeTrue -Because "database build for $($row.instanceName)/$($row.database) should succeed"
        $row.error | Should -BeNullOrEmpty -Because 'no errors expected on the happy path'
      }
    }

    It 'calls Install-SqlServerInstance once per instance' {
      New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      Should -Invoke -CommandName 'Install-SqlServerInstance' -Times 2 -Exactly
    }

    It 'calls Build-DatabaseWithFlyway once per (instance × database) pair' {
      New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      # 2 instances × 2 databases = 4 Build-DatabaseWithFlyway calls
      Should -Invoke -CommandName 'Build-DatabaseWithFlyway' -Times 4 -Exactly
    }

    It 'passes the correct DatabaseName to every Build-DatabaseWithFlyway call' {
      New-SprintSqlServerInstances `
        -InstanceNames @('Development') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      Should -Invoke -CommandName 'Build-DatabaseWithFlyway' -Times 1 -ParameterFilter {
        $DatabaseName -eq 'ATAPUtilities'
      }
      Should -Invoke -CommandName 'Build-DatabaseWithFlyway' -Times 1 -ParameterFilter {
        $DatabaseName -eq 'AceCommander'
      }
    }
  }

  Context 'idempotency — when both instances already exist but databases do not' {

    BeforeEach {
      # Mock Get-Service to report that both instances already exist
      Mock -CommandName 'Get-Service' -MockWith {
        [PSCustomObject]@{ Name = $Name; Status = 'Running' }
      } -ParameterFilter { $Name -like 'MSSQL$*' }

      Mock -CommandName 'Install-SqlServerInstance' -MockWith { [PSCustomObject]@{ Success = $true; Cancelled = $false } }
      Mock -CommandName 'Build-DatabaseWithFlyway' -MockWith { [PSCustomObject]@{ Success = $true; Errors = @() } }
      # Databases do not yet exist — build should still run
      Mock -CommandName 'Get-DbaDatabase' -MockWith { $null }
    }

    It 'does NOT call Install-SqlServerInstance when instances already exist' {
      New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      Should -Invoke -CommandName 'Install-SqlServerInstance' -Times 0 -Exactly
    }

    It 'still builds all databases when instances already exist' {
      $results = New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      Should -Invoke -CommandName 'Build-DatabaseWithFlyway' -Times 4 -Exactly

      foreach ($row in $results) {
        $row.instanceReady | Should -BeTrue
        $row.built | Should -BeTrue
        $row.error | Should -BeNullOrEmpty
      }
    }
  }

  Context 'idempotency — when both instances AND databases already exist' {

    BeforeEach {
      # Both instances exist
      Mock -CommandName 'Get-Service' -MockWith {
        [PSCustomObject]@{ Name = $Name; Status = 'Running' }
      } -ParameterFilter { $Name -like 'MSSQL$*' }

      # Both databases already exist on each instance
      Mock -CommandName 'Get-DbaDatabase' -MockWith {
        [PSCustomObject]@{ Name = $Database; SqlInstance = $SqlInstance }
      }

      Mock -CommandName 'Install-SqlServerInstance' -MockWith { [PSCustomObject]@{ Success = $true; Cancelled = $false } }
      Mock -CommandName 'Build-DatabaseWithFlyway' -MockWith { [PSCustomObject]@{ Success = $true; Errors = @() } }
    }

    It 'does NOT call Install-SqlServerInstance when instances already exist' {
      New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      Should -Invoke -CommandName 'Install-SqlServerInstance' -Times 0 -Exactly
    }

    It 'does NOT call Build-DatabaseWithFlyway when databases already exist' {
      New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      Should -Invoke -CommandName 'Build-DatabaseWithFlyway' -Times 0 -Exactly
    }

    It 'returns all rows with instanceReady and built = $true and no errors' {
      $results = New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      $results.Count | Should -Be 4
      foreach ($row in $results) {
        $row.instanceReady | Should -BeTrue
        $row.built | Should -BeTrue
        $row.error | Should -BeNullOrEmpty
      }
    }
  }

  Context '-WhatIf support' {

    BeforeEach {
      Mock -CommandName 'Get-Service' -MockWith { $null }
      Mock -CommandName 'Install-SqlServerInstance' -MockWith { [PSCustomObject]@{ Success = $true; Cancelled = $false } }
      Mock -CommandName 'Build-DatabaseWithFlyway' -MockWith { [PSCustomObject]@{ Success = $true; Errors = @() } }
      Mock -CommandName 'Get-DbaDatabase' -MockWith { $null }
    }

    It 'does not call Install-SqlServerInstance or Build-DatabaseWithFlyway when -WhatIf is set' {
      New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot `
        -WhatIf

      Should -Invoke -CommandName 'Install-SqlServerInstance' -Times 0 -Exactly
      Should -Invoke -CommandName 'Build-DatabaseWithFlyway' -Times 0 -Exactly
    }
  }

  Context 'default parameter population' {

    BeforeEach {
      Mock -CommandName 'Get-Service' -MockWith {
        [PSCustomObject]@{ Name = $Name; Status = 'Running' }
      } -ParameterFilter { $Name -like 'MSSQL$*' }

      Mock -CommandName 'Build-DatabaseWithFlyway' -MockWith { [PSCustomObject]@{ Success = $true; Errors = @() } }
      Mock -CommandName 'Get-DbaDatabase' -MockWith { $null }
    }

    It 'uses Dev<username> and Exp<username> as default InstanceNames' {
      $results = New-SprintSqlServerInstances `
        -Databases @('ATAPUtilities') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      $expected = @("Dev$($env:USERNAME)", "Exp$($env:USERNAME)") | Sort-Object
      ($results | Select-Object -ExpandProperty instanceName | Sort-Object -Unique) |
        Should -Be $expected
    }

    It 'uses ATAPUtilities and AceCommander as default Databases' {
      $results = New-SprintSqlServerInstances `
        -InstanceNames @('Development') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      ($results | Select-Object -ExpandProperty database | Sort-Object -Unique) |
        Should -Be @('AceCommander', 'ATAPUtilities')
    }
  }

  Context 'when Install-SqlServerInstance returns Cancelled=True' {

    BeforeEach {
      Mock -CommandName 'Get-Service' -MockWith { $null } -ParameterFilter { $Name -like 'MSSQL$*' }
      Mock -CommandName 'Install-SqlServerInstance' -MockWith {
        [PSCustomObject]@{ Success = $false; Cancelled = $true }
      }
      Mock -CommandName 'Build-DatabaseWithFlyway' -MockWith { [PSCustomObject]@{ Success = $true; Errors = @() } }
    }

    It 'marks instanceReady as $false and does not attempt database build' {
      $results = New-SprintSqlServerInstances `
        -InstanceNames @('Experimental') `
        -Databases @('ATAPUtilities') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      $results.Count | Should -Be 1
      $results[0].instanceReady | Should -BeFalse
      $results[0].built | Should -BeFalse
      $results[0].error | Should -Match 'cancelled'

      Should -Invoke -CommandName 'Build-DatabaseWithFlyway' -Times 0 -Exactly
    }
  }
}
