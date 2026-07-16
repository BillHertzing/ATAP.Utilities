#Requires -Version 7.0

Describe 'Install-SqlServerInstance topology integration' -Tag 'Unit' {
  BeforeAll {
    $script:savedConfigRootKeys = $global:configRootKeys
    $script:savedSettings = $global:settings
    $script:savedComputerName = $env:COMPUTERNAME

    if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
      function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
      $script:createdWritePSFMessageStub = $true
    }
    if (-not (Get-Command Get-SecretATAP -ErrorAction SilentlyContinue)) {
      function global:Get-SecretATAP { param($SecretName, $SecretField) }
      $script:createdGetSecretATAPStub = $true
    }
    if (-not (Get-Command Set-DbatoolsConfig -ErrorAction SilentlyContinue)) {
      function global:Set-DbatoolsConfig { param($Name, $Value) }
      $script:createdSetDbatoolsConfigStub = $true
    }
    if (-not (Get-Command Install-DbaInstance -ErrorAction SilentlyContinue)) {
      function global:Install-DbaInstance { param($SqlInstance, $DataPath, $LogPath, $BackupPath) }
      $script:createdInstallDbaInstanceStub = $true
    }

    . (Join-Path $PSScriptRoot '..\..\public\Install-SqlServerInstance.ps1')
    . (Join-Path $PSScriptRoot '..\..\private\Set-SqlServerSystemDatabaseTopology.ps1')
  }

  BeforeEach {
    $script:installDbaInstanceParameters = $null
    $env:COMPUTERNAME = 'UTAT022'
    $global:configRootKeys = @{
      SqlInstanceTopologyConfigRootKey             = 'SqlInstanceTopology'
      SqlInstanceTopologyHostsConfigRootKey        = 'Hosts'
      SqlInstanceTopologyInstancesConfigRootKey    = 'Instances'
      SqlInstanceTopologyInstanceNameConfigRootKey = 'InstanceName'
      SqlInstanceTopologyDataPathConfigRootKey     = 'DataPath'
      SqlInstanceTopologyLogPathConfigRootKey      = 'LogPath'
      SqlInstanceTopologyBackupPathConfigRootKey   = 'BackupPath'
      SqlInstanceTopologyTcpPortConfigRootKey      = 'TcpPort'
    }
    $global:settings = @{
      SqlInstanceTopology = @{
        Hosts = @{
          utat022 = @{
            Instances = @{
              PRODUCTION = @{
                InstanceName = 'PRODUCTION'
                DataPath = 'C:\LocalDBs\PRODUCTION\Data\'
                LogPath = 'C:\LocalDBs\PRODUCTION\Log\'
                BackupPath = 'C:\LocalDBs\PRODUCTION\Backup\'
                TcpPort = 50020
              }
            }
          }
        }
      }
    }

    Mock -CommandName Get-Module -MockWith { [pscustomobject]@{ Name = 'dbatools' } }
    Mock -CommandName Import-Module
    Mock -CommandName Test-Path -MockWith { $true }
    Mock -CommandName Set-DbatoolsConfig
    Mock -CommandName Set-SqlServerSystemDatabaseTopology -MockWith {
      [pscustomobject]@{ Changed = $true; Passed = $true }
    }
    Mock -CommandName Install-DbaInstance -MockWith {
      param($SqlInstance, $DataPath, $LogPath, $BackupPath, $TempPath, $Configuration, $Port, $EngineCredential)
      $script:installDbaInstanceParameters = [pscustomobject]@{
        SqlInstance = $SqlInstance
        DataPath = $DataPath
        LogPath = $LogPath
        BackupPath = $BackupPath
        TempPath = $TempPath
        Configuration = $Configuration
        Port = $Port
        EngineCredential = $EngineCredential
      }
      [pscustomobject]@{ Installed = $true }
    }
  }

  AfterAll {
    $global:configRootKeys = $script:savedConfigRootKeys
    $global:settings = $script:savedSettings
    $env:COMPUTERNAME = $script:savedComputerName
    if ($script:createdWritePSFMessageStub) { Remove-Item 'Function:\Write-PSFMessage' -ErrorAction SilentlyContinue }
    if ($script:createdGetSecretATAPStub) { Remove-Item 'Function:\Get-SecretATAP' -ErrorAction SilentlyContinue }
    if ($script:createdSetDbatoolsConfigStub) { Remove-Item 'Function:\Set-DbatoolsConfig' -ErrorAction SilentlyContinue }
    if ($script:createdInstallDbaInstanceStub) { Remove-Item 'Function:\Install-DbaInstance' -ErrorAction SilentlyContinue }
  }

  It 'passes the current host topology paths to Install-DbaInstance' {
    $result = Install-SqlServerInstance -DatabaseHost localhost -SqlInstance PRODUCTION `
      -SqlServerSetupPath 'C:\Setup' -Confirm:$false

    Should -Invoke Install-DbaInstance -Times 1 -Exactly
    $script:installDbaInstanceParameters.SqlInstance | Should -Be 'localhost\PRODUCTION'
    $script:installDbaInstanceParameters.DataPath | Should -Be 'C:\LocalDBs\PRODUCTION\Data\'
    $script:installDbaInstanceParameters.LogPath | Should -Be 'C:\LocalDBs\PRODUCTION\Log\'
    $script:installDbaInstanceParameters.BackupPath | Should -Be 'C:\LocalDBs\PRODUCTION\Backup\'
    $script:installDbaInstanceParameters.TempPath | Should -Be 'C:\LocalDBs\PRODUCTION\Data\'
    $script:installDbaInstanceParameters.Configuration.SQLTEMPDBLOGDIR | Should -Be 'C:\LocalDBs\PRODUCTION\Log\'
    $script:installDbaInstanceParameters.Port | Should -Be 50020
    Should -Invoke Set-SqlServerSystemDatabaseTopology -Times 1 -Exactly -ParameterFilter {
      $DataPath -eq 'C:\LocalDBs\PRODUCTION\Data\' -and $LogPath -eq 'C:\LocalDBs\PRODUCTION\Log\'
    }
    $result.DataPath | Should -Be 'C:\LocalDBs\PRODUCTION\Data\'
    $result.LogPath | Should -Be 'C:\LocalDBs\PRODUCTION\Log\'
    $result.BackupPath | Should -Be 'C:\LocalDBs\PRODUCTION\Backup\'
  }

  It 'fails before provisioning when the topology is unavailable' {
    $global:settings = @{}

    { Install-SqlServerInstance -DatabaseHost localhost -SqlInstance PRODUCTION `
        -SqlServerSetupPath 'C:\Setup' -Confirm:$false } |
      Should -Throw -ExpectedMessage '*topology is unavailable*'
    Should -Invoke Install-DbaInstance -Times 0 -Exactly
  }

  It 'passes the engine service credential resolved only by SecretName' {
    Mock -CommandName Get-SecretATAP -MockWith {
      if ($SecretField -eq 'username') { '.\SvcSQLServer' } else { 'test-only-password' }
    }

    $result = Install-SqlServerInstance -DatabaseHost localhost -SqlInstance PRODUCTION `
      -EngineCredentialSecretName 'SvcSQLServer.utat022' -SqlServerSetupPath 'C:\Setup' -Confirm:$false

    Should -Invoke Get-SecretATAP -Times 2 -Exactly
    $script:installDbaInstanceParameters.EngineCredential.UserName | Should -Be '.\SvcSQLServer'
    $result.EngineCredentialSecretName | Should -Be 'SvcSQLServer.utat022'
  }

  It 'passes a pre-resolved engine service credential without consulting the secret store' {
    Mock -CommandName Get-SecretATAP -MockWith { throw 'The secret store must not be consulted.' }
    $credential = [System.Management.Automation.PSCredential]::new(
      '.\SvcSQLServer', (ConvertTo-SecureString 'test-only-password' -AsPlainText -Force))

    Install-SqlServerInstance -DatabaseHost localhost -SqlInstance PRODUCTION `
      -EngineCredential $credential -SqlServerSetupPath 'C:\Setup' -Confirm:$false | Out-Null

    Should -Invoke Get-SecretATAP -Times 0 -Exactly
    $script:installDbaInstanceParameters.EngineCredential.UserName | Should -Be '.\SvcSQLServer'
  }
}
