BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  function global:Get-PVal {
    param($ParameterName, $originalPSBoundParameters, $dottedPath, $DefaultValue)
    return $DefaultValue
  }

  function global:Get-DbaRegisteredServer { @() }
  function global:Connect-DbaInstance { param($SqlInstance) [PSCustomObject]@{ Name = $SqlInstance } }
  function global:Get-DbaDatabase { param($SqlInstance, $Database) [PSCustomObject]@{ Name = $Database; SqlInstance = $SqlInstance } }
  function global:Remove-DbaDatabase { param($SqlInstance, $Database, [switch]$Confirm) }
  function global:Start-Process { [PSCustomObject]@{ ExitCode = 0 } }
  function Resolve-BuildToolingDatabaseSqlConnection { throw 'Resolve-BuildToolingDatabaseSqlConnection should not be called by Remove-DeveloperSqlServerInstances.' }
  function Invoke-BuildToolingSqlQuery { throw 'Invoke-BuildToolingSqlQuery should not be called by Remove-DeveloperSqlServerInstances.' }

  . "$PSScriptRoot\..\..\public\Remove-DeveloperSqlServerInstances.ps1"
}

Describe 'Remove-DeveloperSqlServerInstances [public]' {
  BeforeEach {
    $script:setupDir = Join-Path ([System.IO.Path]::GetTempPath()) "rsssi_$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:setupDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $script:setupDir 'setup.exe') -Value 'stub' -Encoding UTF8

    Mock -CommandName Get-DbaRegisteredServer -MockWith { @() }
    Mock -CommandName Connect-DbaInstance -MockWith {
      param($SqlInstance)
      [PSCustomObject]@{ Name = $SqlInstance }
    }
    Mock -CommandName Get-DbaDatabase -MockWith {
      param($SqlInstance, $Database)
      [PSCustomObject]@{ Name = $Database; SqlInstance = $SqlInstance }
    }
    Mock -CommandName Remove-DbaDatabase -MockWith {}
    Mock -CommandName Start-Process -MockWith { [PSCustomObject]@{ ExitCode = 0 } }
    Mock -CommandName Resolve-BuildToolingDatabaseSqlConnection -MockWith {
      throw 'Resolve-BuildToolingDatabaseSqlConnection should not be called by Remove-DeveloperSqlServerInstances.'
    }
    Mock -CommandName Invoke-BuildToolingSqlQuery -MockWith {
      throw 'Invoke-BuildToolingSqlQuery should not be called by Remove-DeveloperSqlServerInstances.'
    }
  }

  AfterEach {
    Remove-Item -LiteralPath $script:setupDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'does not drop databases when WhatIf is set' {
    Remove-DeveloperSqlServerInstances `
      -DeveloperNames @('tester') `
      -SqlServerSetupPath $script:setupDir `
      -WhatIf | Out-Null

    Should -Invoke -CommandName Remove-DbaDatabase -Times 0 -Exactly
    Should -Invoke -CommandName Start-Process -Times 0 -Exactly
  }

  It 'drops ATAPUtilities and AceCommander for each sprint instance when not WhatIf' {
    Remove-DeveloperSqlServerInstances `
      -DeveloperNames @('tester') `
      -SqlServerSetupPath $script:setupDir `
      -Confirm:$false | Out-Null

    Should -Invoke -CommandName Remove-DbaDatabase -Times 4 -Exactly
    Should -Invoke -CommandName Remove-DbaDatabase -Times 2 -ParameterFilter { $Database -eq 'ATAPUtilities' }
    Should -Invoke -CommandName Remove-DbaDatabase -Times 2 -ParameterFilter { $Database -eq 'AceCommander' }
  }

  It 'does not require a BuildTooling SqlConnection for instance removal' {
    Remove-DeveloperSqlServerInstances `
      -DeveloperNames @('tester') `
      -SqlServerSetupPath $script:setupDir `
      -Confirm:$false | Out-Null

    Should -Invoke -CommandName Resolve-BuildToolingDatabaseSqlConnection -Times 0 -Exactly
    Should -Invoke -CommandName Invoke-BuildToolingSqlQuery -Times 0 -Exactly
    Should -Invoke -CommandName Connect-DbaInstance -Times 2 -Exactly
    Should -Invoke -CommandName Start-Process -Times 2 -Exactly
  }
}
