#Requires -Version 7.0
# Pester 5+ tests for DatabaseProvisioning path safety.

BeforeAll {
  $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $publicDir = Join-Path $moduleRoot 'public'

  try {
    Add-Type -AssemblyName 'Microsoft.Data.SqlClient' -ErrorAction Stop
  } catch {
    Import-Module dbatools -ErrorAction SilentlyContinue
  }

  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
    $script:createdWritePSFMessageStub = $true
  }

  if (-not (Get-Command Get-RepositoryRoot -ErrorAction SilentlyContinue)) {
    function global:Get-RepositoryRoot { return $script:moduleRoot }
    $script:createdGetRepositoryRootStub = $true
  }

  if (-not (Get-Command Get-PVal -ErrorAction SilentlyContinue)) {
    function global:Get-PVal {
      param(
        [string]$ParameterName,
        [hashtable]$originalPSBoundParameters,
        [string]$dottedPath,
        [hashtable]$Settings,
        [AllowNull()]$DefaultValue,
        [switch]$AllowMissing,
        [type]$AsType,
        [string[]]$ValidValues
      )

      if ($originalPSBoundParameters -and $originalPSBoundParameters.ContainsKey($ParameterName)) {
        return $originalPSBoundParameters[$ParameterName]
      }

      if ($Settings -and -not [string]::IsNullOrWhiteSpace($dottedPath)) {
        $current = $Settings
        $found = $true
        foreach ($part in ($dottedPath -split '\.')) {
          if ($current -is [System.Collections.IDictionary] -and $current.Contains($part)) {
            $current = $current[$part]
            continue
          }

          if ($null -ne $current -and $current.PSObject.Properties[$part]) {
            $current = $current.PSObject.Properties[$part].Value
            continue
          }

          $found = $false
          break
        }

        if ($found) {
          if ($null -ne $AsType -and $null -ne $current) {
            return ($current -as $AsType)
          }
          return $current
        }
      }

      if ($PSBoundParameters.ContainsKey('DefaultValue')) {
        if ($null -ne $AsType -and $null -ne $DefaultValue) {
          return ($DefaultValue -as $AsType)
        }
        return $DefaultValue
      }

      if ($AllowMissing) {
        return $null
      }

      throw "Missing test value for $ParameterName"
    }
    $script:createdGetPValStub = $true
  }

  if (-not (Get-Command Resolve-DatabaseSqlConnection -ErrorAction SilentlyContinue)) {
    function global:Resolve-DatabaseSqlConnection {
      param(
        [hashtable]$OriginalPSBoundParameters,
        [object]$SqlConnection,
        [string]$DBConnectionStringSecretName,
        [string]$DBConnectionStringMasterSecretName,
        [string]$DatabaseHost,
        [string]$InstanceName,
        [string]$DatabaseName,
        [string]$ConnectionMethod,
        [string]$CredentialsKey,
        [string]$ApplicationName,
        [switch]$UseTrustedConnection,
        [switch]$IntegratedSecurity,
        [hashtable]$Settings,
        [string]$DatabaseHostDottedPath,
        [string]$DBConnectionStringSecretNameDottedPath,
        [string]$DBConnectionStringMasterSecretNameDottedPath,
        [string]$InstanceNameDottedPath,
        [string]$ConnectionMethodDottedPath,
        [string]$CredentialsKeyDottedPath,
        [string]$ApplicationNameDottedPath
      )
    }
    $script:createdResolveDatabaseSqlConnectionStub = $true
  }

  if (-not (Get-Command Invoke-DatabaseSqlScalar -ErrorAction SilentlyContinue)) {
    function global:Invoke-DatabaseSqlScalar {
      param([object]$SqlConnection, [string]$CommandText, [hashtable]$Parameters, [int]$CommandTimeout)
    }
    $script:createdInvokeDatabaseSqlScalarStub = $true
  }

  if (-not (Get-Command Invoke-DatabaseSqlNonQuery -ErrorAction SilentlyContinue)) {
    function global:Invoke-DatabaseSqlNonQuery {
      param([object]$SqlConnection, [string]$CommandText, [hashtable]$Parameters, [int]$CommandTimeout)
    }
    $script:createdInvokeDatabaseSqlNonQueryStub = $true
  }

  . (Join-Path $publicDir 'DatabaseProvisioning.ps1')
}

AfterAll {
  foreach ($item in @(
      @{ Created = $script:createdWritePSFMessageStub; Name = 'Write-PSFMessage' }
      @{ Created = $script:createdGetRepositoryRootStub; Name = 'Get-RepositoryRoot' }
      @{ Created = $script:createdGetPValStub; Name = 'Get-PVal' }
      @{ Created = $script:createdResolveDatabaseSqlConnectionStub; Name = 'Resolve-DatabaseSqlConnection' }
      @{ Created = $script:createdInvokeDatabaseSqlScalarStub; Name = 'Invoke-DatabaseSqlScalar' }
      @{ Created = $script:createdInvokeDatabaseSqlNonQueryStub; Name = 'Invoke-DatabaseSqlNonQuery' }
    )) {
    if ($item.Created) {
      Remove-Item -LiteralPath "Function:\$($item.Name)" -ErrorAction SilentlyContinue
    }
  }
}

Describe 'DatabaseProvisioning database folder handling' -Tag 'Unit' {
  BeforeEach {
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('dbprov-test-' + [guid]::NewGuid().ToString('N'))
    $script:provisioningPath = Join-Path $script:tempRoot 'provisioning'
    $script:databasePath = Join-Path (Join-Path $script:tempRoot 'data') 'ATAPUtilities'
    New-Item -ItemType Directory -Path $script:provisioningPath -Force | Out-Null
    New-Item -ItemType Directory -Path $script:databasePath -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $script:databasePath 'stale.txt') -Value 'old data' -Encoding UTF8

    foreach ($scriptName in @('DropAndCreateDatabase.sql', 'CreateLoginAndUser.sql', 'AddFlywaySchemaHistoryTable.sql')) {
      Set-Content -LiteralPath (Join-Path $script:provisioningPath $scriptName) -Value 'SELECT 1;' -Encoding UTF8
    }

    $fakeConnection = [PSCustomObject]@{
      ConnectionString = 'Data Source=tcp:localhost\Devtest;Initial Catalog=master;Integrated Security=True;TrustServerCertificate=True'
      DataSource       = 'tcp:localhost\Devtest'
      State            = 'Open'
    }
    $fakeConnection | Add-Member -MemberType ScriptMethod -Name Close -Value { }
    $fakeConnection | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
    $script:fakeConnection = $fakeConnection

    Mock Resolve-DatabaseSqlConnection {
      [PSCustomObject]@{
        Connection    = $script:fakeConnection
        IsCallerOwned = $false
      }
    }
    Mock Invoke-DatabaseSqlScalar { $false }
    Mock Invoke-DatabaseSqlNonQuery { 0 }
  }

  AfterEach {
    Remove-Item -LiteralPath $script:tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'fails when the database folder already exists and -Force is not supplied' {
    {
      DatabaseProvisioning `
        -DatabaseName 'ATAPUtilities' `
        -Environment 'Development' `
        -DatabaseHost 'localhost' `
        -SqlInstance 'Devtest' `
        -IntegratedSecurity `
        -DatabasePath $script:databasePath `
        -ProvisioningScriptsPath $script:provisioningPath `
        -Confirm:$false
    } | Should -Throw -ExpectedMessage '*already exists*Use -Force*'

    Test-Path -LiteralPath $script:databasePath -PathType Container | Should -BeTrue
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 0 -Exactly -Scope It
  }

  It 'removes the existing database folder and provisions when -Force is supplied' {
    $result = DatabaseProvisioning `
      -DatabaseName 'ATAPUtilities' `
      -Environment 'Development' `
      -DatabaseHost 'localhost' `
      -SqlInstance 'Devtest' `
      -IntegratedSecurity `
      -DatabasePath $script:databasePath `
      -ProvisioningScriptsPath $script:provisioningPath `
      -Force `
      -Confirm:$false

    $result.Success | Should -BeTrue
    Test-Path -LiteralPath $script:databasePath -PathType Container | Should -BeTrue
    Test-Path -LiteralPath (Join-Path $script:databasePath 'stale.txt') | Should -BeFalse
    Assert-MockCalled Invoke-DatabaseSqlNonQuery -Times 3 -Exactly -Scope It
  }

  It 'resolves DBConnectionStringMasterSecretName from per-database settings before opening the SQL connection' {
    $settings = @{
      ATAPUtilities = @{
        Development = @{
          DBConnectionStringMasterSecretName = 'ATAPUtilitiesDevelopmentMasterConnectionString'
          DatabasePath                 = $script:databasePath
          ProvisioningScriptsPath      = $script:provisioningPath
        }
      }
    }

    DatabaseProvisioning `
      -DatabaseName 'ATAPUtilities' `
      -Environment 'Development' `
      -Settings $settings `
      -Force `
      -Confirm:$false | Out-Null

    Assert-MockCalled Resolve-DatabaseSqlConnection -Times 1 -Exactly -Scope It -ParameterFilter {
      $DBConnectionStringMasterSecretName -eq 'ATAPUtilitiesDevelopmentMasterConnectionString' -and
      $DBConnectionStringMasterSecretNameDottedPath -eq 'ATAPUtilities.Development.DBConnectionStringMasterSecretName'
    }
  }

  It 'uses C:\LocalDBs as the default database root' {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $provisioningSource = Get-Content -LiteralPath (Join-Path $moduleRoot 'public\DatabaseProvisioning.ps1') -Raw
    $buildSource = Get-Content -LiteralPath (Join-Path $moduleRoot 'public\Build-DatabaseWithFlyway.ps1') -Raw

    $provisioningSource | Should -Match ([regex]::Escape("'C:\LocalDBs'"))
    $buildSource | Should -Match ([regex]::Escape("'C:\LocalDBs'"))
    $provisioningSource | Should -Match 'Join-Path \$databaseRootPath \$DatabaseName'
    $buildSource | Should -Match 'Join-Path \$databaseRootPath \$DatabaseName'
  }
}

Describe 'DropAndCreateDatabase SQL path guard' -Tag 'Unit' {
  It 'checks SQL Server-visible path existence without calling xp_create_subdir' {
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $srcRoot = Split-Path -Parent $moduleRoot
    $scriptPath = Join-Path $srcRoot 'ATAP.Utilities.DatabaseManagement\SharedSQL\DropAndCreateDatabase.sql'
    $scriptText = Get-Content -LiteralPath $scriptPath -Raw

    $scriptText | Should -Match 'xp_fileexist'
    $scriptText | Should -Match 'IF @IsDirectory = 0'
    $scriptText | Should -Not -Match 'xp_create_subdir'
    $scriptText | Should -Match 'DatabasePath exists as a file'
    $scriptText | Should -Match 'DatabasePath does not exist or SQL Server cannot access it'
  }
}
