BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  function global:Get-DbaDatabase {
    [CmdletBinding()]
    param($SqlInstance, $Database)
    [PSCustomObject]@{ Name = $Database; SqlInstance = $SqlInstance }
  }
  function global:Remove-DbaDatabase {
    [CmdletBinding(SupportsShouldProcess)]
    param($SqlInstance, $Database, [switch]$EnableException)
  }
  function global:Install-SqlServerInstance { throw 'Remove-SprintDatabases must not create SQL Server instances.' }
  function global:Build-DatabaseWithFlyway { throw 'Remove-SprintDatabases must not run Flyway migrations.' }

  . "$PSScriptRoot\..\..\public\Remove-SprintDatabases.ps1"
}

Describe 'Remove-SprintDatabases [public]' {
  BeforeEach {
    Mock -CommandName Get-Service -MockWith {
      [PSCustomObject]@{ Name = $Name; Status = 'Running' }
    } -ParameterFilter { $Name -like 'MSSQL$*' }

    Mock -CommandName Get-DbaDatabase -MockWith {
      param($SqlInstance, $Database)
      [PSCustomObject]@{ Name = $Database; SqlInstance = $SqlInstance }
    }
    Mock -CommandName Remove-DbaDatabase -MockWith {
      [PSCustomObject]@{ ComputerName = 'fixture'; InstanceName = $SqlInstance; SqlInstance = $SqlInstance; Database = $Database; Status = 'Dropped' }
    }
    Mock -CommandName Install-SqlServerInstance -MockWith { throw 'Must not be called.' }
    Mock -CommandName Build-DatabaseWithFlyway -MockWith { throw 'Must not be called.' }
  }

  It 'function exists and is loaded' {
    Get-Command -Name 'Remove-SprintDatabases' -CommandType Function |
      Should -Not -BeNullOrEmpty
  }

  It 'calls Remove-DbaDatabase once per instance and database' {
    $results = Remove-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities', 'AceCommander') `
      -Confirm:$false

    $results.Count | Should -Be 4
    Should -Invoke -CommandName Remove-DbaDatabase -Times 4 -Exactly
  }

  It 'calls Remove-DbaDatabase for each database on each instance' {
    Remove-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities', 'AceCommander') `
      -Confirm:$false | Out-Null

    Should -Invoke -CommandName Remove-DbaDatabase -Times 2 -ParameterFilter { $Database -eq 'ATAPUtilities' }
    Should -Invoke -CommandName Remove-DbaDatabase -Times 2 -ParameterFilter { $Database -eq 'AceCommander' }
  }

  It 'returns one typed result when dbatools emits a status object and requests terminating errors' {
    $results = @(Remove-SprintDatabases -InstanceNames 'Devtester' -Databases 'ATAPUtilities' -Confirm:$false)

    $results.Count | Should -Be 1
    $results[0].dropped | Should -BeTrue
    $results[0].error | Should -BeNullOrEmpty
    @($results[0].PSObject.Properties.Name | Sort-Object) -join ',' |
      Should -Be 'database,dropped,dryRun,environment,error,instanceName,instanceReady,skipped'
    Should -Invoke -CommandName Remove-DbaDatabase -Times 1 -Exactly -ParameterFilter {
      $EnableException -eq $true -and $ErrorAction -eq 'Stop'
    }
  }

  It 'suppresses multiple dbatools status objects for the same database' {
    Mock Remove-DbaDatabase {
      [PSCustomObject]@{ SqlInstance = $SqlInstance; Database = $Database; Status = 'Starting' }
      [PSCustomObject]@{ SqlInstance = $SqlInstance; Database = $Database; Status = 'Dropped' }
      [PSCustomObject]@{ SqlInstance = $SqlInstance; Database = $Database; Status = 'Complete' }
    }

    $results = @(Remove-SprintDatabases -InstanceNames 'Devtester' -Databases 'ATAPUtilities' -Confirm:$false)

    $results.Count | Should -Be 1
    $results[0].dropped | Should -BeTrue
    $results[0].database | Should -Be 'ATAPUtilities'
    $results[0].PSObject.Properties.Name | Should -Not -Contain 'Status'
  }

  It 'returns one typed error row without claiming a drop after a terminating failure and partial status output' {
    Mock Remove-DbaDatabase {
      [PSCustomObject]@{ SqlInstance = $SqlInstance; Database = $Database; Status = 'Starting' }
      throw 'Fixture terminating dbatools failure'
    }

    $results = @(Remove-SprintDatabases -InstanceNames 'Devtester' -Databases 'ATAPUtilities' -Confirm:$false)

    $results.Count | Should -Be 1
    $results[0].dropped | Should -BeFalse
    $results[0].skipped | Should -BeFalse
    $results[0].error | Should -Match 'Fixture terminating dbatools failure'
  }

  It 'promotes a nonterminating error to one typed failure row without claiming a drop' {
    Mock Remove-DbaDatabase {
      [PSCustomObject]@{ SqlInstance = $SqlInstance; Database = $Database; Status = 'Starting' }
      Write-Error -Message 'Fixture nonterminating dbatools failure'
    }

    $results = @(Remove-SprintDatabases -InstanceNames 'Devtester' -Databases 'ATAPUtilities' -Confirm:$false)

    $results.Count | Should -Be 1
    $results[0].dropped | Should -BeFalse
    $results[0].error | Should -Match 'Fixture nonterminating dbatools failure'
    Should -Invoke -CommandName Remove-DbaDatabase -Times 1 -Exactly -ParameterFilter {
      $EnableException -eq $true -and $ErrorAction -eq 'Stop'
    }
  }

  It 'keeps exactly one typed row per database when a failure precedes a successful database' {
    Mock Remove-DbaDatabase {
      if ($Database -eq 'FailsFirst') { throw 'Fixture first database failure' }
      [PSCustomObject]@{ SqlInstance = $SqlInstance; Database = $Database; Status = 'Dropped' }
      [PSCustomObject]@{ SqlInstance = $SqlInstance; Database = $Database; Status = 'Complete' }
    }

    $results = @(Remove-SprintDatabases -InstanceNames 'Devtester' -Databases @('FailsFirst', 'SucceedsSecond') -Confirm:$false)

    $results.Count | Should -Be 2
    $failed = @($results | Where-Object database -EQ 'FailsFirst')
    $succeeded = @($results | Where-Object database -EQ 'SucceedsSecond')
    $failed.Count | Should -Be 1
    $failed[0].dropped | Should -BeFalse
    $failed[0].error | Should -Match 'Fixture first database failure'
    $succeeded.Count | Should -Be 1
    $succeeded[0].dropped | Should -BeTrue
    $succeeded[0].error | Should -BeNullOrEmpty
  }

  It 'returns one skipped typed row and does not remove an already absent database' {
    Mock Get-DbaDatabase { $null }

    $results = @(Remove-SprintDatabases -InstanceNames 'Devtester' -Databases 'AlreadyAbsent' -Confirm:$false)

    $results.Count | Should -Be 1
    $results[0].database | Should -Be 'AlreadyAbsent'
    $results[0].skipped | Should -BeTrue
    $results[0].dropped | Should -BeFalse
    $results[0].error | Should -BeNullOrEmpty
    Should -Invoke -CommandName Remove-DbaDatabase -Times 0 -Exactly
  }

  It 'fails with onboarding remediation and does not drop anything when an instance is missing' {
    Mock -CommandName Get-Service -MockWith {
      if ($Name -eq 'MSSQL$Devtester') {
        [PSCustomObject]@{ Name = $Name; Status = 'Running' }
      }
      # Exptester not found — returns $null
    } -ParameterFilter { $Name -like 'MSSQL$*' }

    {
      Remove-SprintDatabases `
        -InstanceNames @('Devtester', 'Exptester') `
        -Databases @('ATAPUtilities') `
        -Confirm:$false
    } | Should -Throw -ExpectedMessage '*developer onboarding SQL Server instance setup*'

    Should -Invoke -CommandName Remove-DbaDatabase -Times 0 -Exactly
  }

  It 'does not call Remove-DbaDatabase when WhatIf is set' {
    $results = Remove-SprintDatabases `
      -InstanceNames @('Devtester', 'Exptester') `
      -Databases @('ATAPUtilities', 'AceCommander') `
      -WhatIf

    $results.Count | Should -Be 4
    ($results | Where-Object { -not $_.skipped }).Count | Should -Be 0
    Should -Invoke -CommandName Remove-DbaDatabase -Times 0 -Exactly
  }

  It 'does not call Remove-DbaDatabase when DryRun is set' {
    $results = Remove-SprintDatabases `
      -InstanceNames @('Devtester') `
      -Databases @('ATAPUtilities', 'AceCommander') `
      -DryRun

    $results.Count | Should -Be 2
    ($results | Where-Object { $_.dryRun -and $_.skipped }).Count | Should -Be 2
    ($results | Where-Object { $_.dropped }).Count | Should -Be 0
    Should -Invoke -CommandName Remove-DbaDatabase -Times 0 -Exactly
  }

  It 'uses Dev and Exp instance names for the current user by default' {
    Remove-SprintDatabases `
      -Databases @('ATAPUtilities') `
      -DryRun | Out-Null

    Should -Invoke -CommandName Get-Service -Times 1 -ParameterFilter { $Name -eq "MSSQL`$Dev$($env:USERNAME)" }
    Should -Invoke -CommandName Get-Service -Times 1 -ParameterFilter { $Name -eq "MSSQL`$Exp$($env:USERNAME)" }
  }

  It 'never creates SQL Server instances' {
    Remove-SprintDatabases `
      -InstanceNames @('Devtester') `
      -Databases @('ATAPUtilities') `
      -Confirm:$false | Out-Null

    Should -Invoke -CommandName Install-SqlServerInstance -Times 0 -Exactly
  }

  It 'never runs Flyway migrations' {
    Remove-SprintDatabases `
      -InstanceNames @('Devtester') `
      -Databases @('ATAPUtilities') `
      -Confirm:$false | Out-Null

    Should -Invoke -CommandName Build-DatabaseWithFlyway -Times 0 -Exactly
  }
}
