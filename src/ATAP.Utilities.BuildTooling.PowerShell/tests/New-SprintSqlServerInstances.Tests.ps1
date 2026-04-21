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

  # Minimal stub for Invoke-Flyway — does nothing, simulates success
  function script:Invoke-Flyway {
    param(
      [string]$DatabaseName,
      [string]$Environment,
      [string]$DatabaseHost,
      [string]$SqlInstance,
      [string]$ConnectionMethod,
      [string]$FlywayBasePath,
      [string]$FlywayTomlPath,
      [string]$FlywaySqlMigrationsPath,
      [string]$FlywayCommand,
      [switch]$IntegratedSecurity
    )
    # no-op stub
  }

  # Stub Import-Module so dbatools import check doesn't fail in unit tests
  Mock -CommandName 'Import-Module' -MockWith { } -ParameterFilter { $Name -eq 'dbatools' }

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

  Set-Content -Path (Join-Path $dmPub 'Invoke-Flyway.ps1') `
    -Value @'
function Invoke-Flyway {
    param(
        [string]$DatabaseName, [string]$Environment, [string]$DatabaseHost,
        [string]$SqlInstance, [string]$ConnectionMethod,
        [string]$FlywayBasePath,
        [string]$FlywayTomlPath, [string]$FlywaySqlMigrationsPath, [string]$FlywayCommand,
        [switch]$IntegratedSecurity
    )
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

      # Track Install-SqlServerInstance and Invoke-Flyway calls
      Mock -CommandName 'Install-SqlServerInstance' -MockWith { [PSCustomObject]@{ Success = $true; Cancelled = $false } }
      Mock -CommandName 'Get-DbaDatabase' -MockWith { $null }
      Mock -CommandName 'New-DbaDatabase' -MockWith { [PSCustomObject]@{ Name = $Database } }
      Mock -CommandName 'Invoke-Flyway' -MockWith { }
      Mock -CommandName 'Import-Module' -MockWith { } -ParameterFilter { $Name -eq 'dbatools' }
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
        $row.baselined | Should -BeTrue -Because "baseline for $($row.instanceName)/$($row.database) should succeed"
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

    It 'calls Invoke-Flyway once per (instance × database) pair' {
      New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      # 2 instances × 2 databases = 4 Flyway baseline calls
      Should -Invoke -CommandName 'Invoke-Flyway' -Times 4 -Exactly
    }

    It 'passes FlywayCommand = baseline to every Invoke-Flyway call' {
      New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      Should -Invoke -CommandName 'Invoke-Flyway' -Times 4 -ParameterFilter {
        $FlywayCommand -eq 'baseline'
      }
    }
  }

  Context 'idempotency — when both instances already exist' {

    BeforeEach {
      # Mock Get-Service to report that both instances already exist
      Mock -CommandName 'Get-Service' -MockWith {
        [PSCustomObject]@{ Name = $Name; Status = 'Running' }
      } -ParameterFilter { $Name -like 'MSSQL$*' }

      Mock -CommandName 'Install-SqlServerInstance' -MockWith { [PSCustomObject]@{ Success = $true; Cancelled = $false } }
      Mock -CommandName 'Get-DbaDatabase' -MockWith { [PSCustomObject]@{ Name = $Database } }
      Mock -CommandName 'New-DbaDatabase' -MockWith { [PSCustomObject]@{ Name = $Database } }
      Mock -CommandName 'Invoke-Flyway' -MockWith { }
      Mock -CommandName 'Import-Module' -MockWith { } -ParameterFilter { $Name -eq 'dbatools' }
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

    It 'still baselines all databases when instances already exist' {
      $results = New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      Should -Invoke -CommandName 'Invoke-Flyway' -Times 4 -Exactly

      foreach ($row in $results) {
        $row.instanceReady | Should -BeTrue
        $row.baselined | Should -BeTrue
        $row.error | Should -BeNullOrEmpty
      }
    }
  }

  Context '-WhatIf support' {

    BeforeEach {
      Mock -CommandName 'Get-Service' -MockWith { $null }
      Mock -CommandName 'Install-SqlServerInstance' -MockWith { [PSCustomObject]@{ Success = $true; Cancelled = $false } }
      Mock -CommandName 'Get-DbaDatabase' -MockWith { $null }
      Mock -CommandName 'New-DbaDatabase' -MockWith { [PSCustomObject]@{ Name = $Database } }
      Mock -CommandName 'Invoke-Flyway' -MockWith { }
      Mock -CommandName 'Import-Module' -MockWith { } -ParameterFilter { $Name -eq 'dbatools' }
    }

    It 'does not call Install-SqlServerInstance or Invoke-Flyway when -WhatIf is set' {
      New-SprintSqlServerInstances `
        -InstanceNames @('Development', 'Experimental') `
        -Databases @('ATAPUtilities', 'AceCommander') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot `
        -WhatIf

      Should -Invoke -CommandName 'Install-SqlServerInstance' -Times 0 -Exactly
      Should -Invoke -CommandName 'Invoke-Flyway' -Times 0 -Exactly
    }
  }

  Context 'default parameter population' {

    BeforeEach {
      Mock -CommandName 'Get-Service' -MockWith {
        [PSCustomObject]@{ Name = $Name; Status = 'Running' }
      } -ParameterFilter { $Name -like 'MSSQL$*' }

      Mock -CommandName 'Get-DbaDatabase' -MockWith { [PSCustomObject]@{ Name = $Database } }
      Mock -CommandName 'New-DbaDatabase' -MockWith { [PSCustomObject]@{ Name = $Database } }
      Mock -CommandName 'Invoke-Flyway' -MockWith { }
      Mock -CommandName 'Import-Module' -MockWith { } -ParameterFilter { $Name -eq 'dbatools' }
    }

    It 'uses Development and Experimental as default InstanceNames' {
      $results = New-SprintSqlServerInstances `
        -Databases @('ATAPUtilities') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      ($results | Select-Object -ExpandProperty instanceName | Sort-Object -Unique) |
        Should -Be @('Development', 'Experimental')
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
      Mock -CommandName 'Get-DbaDatabase' -MockWith { $null }
      Mock -CommandName 'New-DbaDatabase' -MockWith { [PSCustomObject]@{ Name = $Database } }
      Mock -CommandName 'Invoke-Flyway' -MockWith { }
      Mock -CommandName 'Import-Module' -MockWith { } -ParameterFilter { $Name -eq 'dbatools' }
    }

    It 'marks instanceReady as $false and does not attempt Flyway baseline' {
      $results = New-SprintSqlServerInstances `
        -InstanceNames @('Experimental') `
        -Databases @('ATAPUtilities') `
        -DatabaseHost 'localhost' `
        -FlywayBasePath $script:flywayBase `
        -RepositoryRoot $script:tempRepoRoot

      $results.Count | Should -Be 1
      $results[0].instanceReady | Should -BeFalse
      $results[0].baselined | Should -BeFalse
      $results[0].error | Should -Match 'cancelled'

      Should -Invoke -CommandName 'Invoke-Flyway' -Times 0 -Exactly
    }
  }
}
