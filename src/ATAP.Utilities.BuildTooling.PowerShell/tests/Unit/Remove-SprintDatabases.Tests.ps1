BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  function global:Get-DbaDatabase {
    param($SqlInstance, $Database)
    [PSCustomObject]@{ Name = $Database; SqlInstance = $SqlInstance }
  }
  function global:Remove-DbaDatabase {
    param($SqlInstance, $Database, [switch]$Confirm)
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
    Mock -CommandName Remove-DbaDatabase -MockWith {}
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
