BeforeAll {
  if (-not (Get-Command Write-PSFMessage -ErrorAction SilentlyContinue)) {
    function global:Write-PSFMessage { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
  }

  . "$PSScriptRoot\..\..\public\Get-DbConnectionStringSecretDescriptor.ps1"
}

Describe 'Get-DbConnectionStringSecretDescriptor [public]' {

  Context 'ByName - BWS-only sprint tiers by default' {
    It 'parses a Dev secret name into parts and classifies it credentialed by default' {
      $d = Get-DbConnectionStringSecretDescriptor -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith'

      $d.DatabaseName | Should -Be 'ATAPUtilities'
      $d.DatabaseHost | Should -Be 'localhost'
      $d.Environment | Should -Be 'Dev'
      $d.UserName | Should -Be 'jsmith'
      $d.Classification | Should -Be 'credentialed'
      $d.IsDerivable | Should -BeFalse
      $d.ConnectionString | Should -BeNullOrEmpty
    }

    It 'builds the exact Integrated-Security connection string format only when explicitly enabled for provisioning' {
      $d = Get-DbConnectionStringSecretDescriptor `
        -SecretName 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith' `
        -DerivableTier @('Dev', 'Exp')

      $d.IsDerivable | Should -BeTrue
      $d.ConnectionString | Should -BeExactly `
        'Server=localhost\Devjsmith;Database=ATAPUtilities;Integrated Security=True;MultipleActiveResultSets=True;TrustServerCertificate=True;'
    }

    It 'parses and builds an Exp secret name when explicitly enabled for provisioning' {
      $d = Get-DbConnectionStringSecretDescriptor `
        -SecretName 'dbConnectionString-master-utat022-Exp-tester' `
        -DerivableTier @('Dev', 'Exp')

      $d.Environment | Should -Be 'Exp'
      $d.ConnectionString | Should -BeExactly `
        'Server=utat022\Exptester;Database=master;Integrated Security=True;MultipleActiveResultSets=True;TrustServerCertificate=True;'
    }

    It 'normalizes the long-form Development/Experimental tokens to Dev/Exp' {
      (Get-DbConnectionStringSecretDescriptor -SecretName 'dbConnectionString-master-localhost-Development-jsmith').Environment | Should -Be 'Dev'
      (Get-DbConnectionStringSecretDescriptor -SecretName 'dbConnectionString-master-localhost-Experimental-jsmith').Environment | Should -Be 'Exp'
    }

    It 'tolerates a hyphenated host by locating the tier token by value' {
      $d = Get-DbConnectionStringSecretDescriptor -SecretName 'dbConnectionString-ATAPUtilities-my-build-box-Dev-jsmith'

      $d.DatabaseHost | Should -Be 'my-build-box'
      $d.Environment | Should -Be 'Dev'
      $d.UserName | Should -Be 'jsmith'
      $d.IsDerivable | Should -BeFalse
    }
  }

  Context 'ByName — credentialed / non-derivable' {
    It 'classifies a permanent tier (Production) credentialed with no connection string' {
      $d = Get-DbConnectionStringSecretDescriptor -SecretName 'dbConnectionString-ATAPUtilities-sql01-Production'

      $d.Environment | Should -Be 'Production'
      $d.UserName | Should -BeNullOrEmpty
      $d.Classification | Should -Be 'credentialed'
      $d.IsDerivable | Should -BeFalse
      $d.ConnectionString | Should -BeNullOrEmpty
    }

    It 'classifies a non-matching secret name credentialed (cannot derive)' {
      $d = Get-DbConnectionStringSecretDescriptor -SecretName 'BuildMaster.Admin.API.Key'

      $d.IsDerivable | Should -BeFalse
      $d.Classification | Should -Be 'credentialed'
      $d.ConnectionString | Should -BeNullOrEmpty
    }

    It 'classifies a dbConnectionString name with no recognizable tier credentialed' {
      $d = Get-DbConnectionStringSecretDescriptor -SecretName 'dbConnectionString-master-localhost-Staging-jsmith'

      $d.IsDerivable | Should -BeFalse
      $d.ConnectionString | Should -BeNullOrEmpty
    }
  }

  Context 'ByParts — build mode' {
    It 'builds the canonical sprint name from parts as BWS-only by default' {
      $d = Get-DbConnectionStringSecretDescriptor -DatabaseName 'master' -DatabaseHost 'localhost' -Environment 'Exp' -UserName 'jsmith'

      $d.SecretName | Should -Be 'dbConnectionString.master.localhost.Exp.jsmith'
      $d.IsDerivable | Should -BeFalse
      $d.ConnectionString | Should -BeNullOrEmpty
    }

    It 'builds the canonical sprint name and provisioning value from parts when explicitly enabled' {
      $d = Get-DbConnectionStringSecretDescriptor `
        -DatabaseName 'master' `
        -DatabaseHost 'localhost' `
        -Environment 'Exp' `
        -UserName 'jsmith' `
        -DerivableTier @('Dev', 'Exp')

      $d.SecretName | Should -Be 'dbConnectionString.master.localhost.Exp.jsmith'
      $d.IsDerivable | Should -BeTrue
      $d.ConnectionString | Should -BeExactly `
        'Server=localhost\Expjsmith;Database=master;Integrated Security=True;MultipleActiveResultSets=True;TrustServerCertificate=True;'
    }

    It 'builds a permanent-tier name without a username and marks it credentialed' {
      $d = Get-DbConnectionStringSecretDescriptor -DatabaseName 'ATAPUtilities' -DatabaseHost 'sql01' -Environment 'QA'

      $d.SecretName | Should -Be 'dbConnectionString.ATAPUtilities.sql01.QA'
      $d.IsDerivable | Should -BeFalse
      $d.ConnectionString | Should -BeNullOrEmpty
    }

    It 'defaults the username to $env:USERNAME for a sprint tier' {
      $d = Get-DbConnectionStringSecretDescriptor -DatabaseName 'master' -DatabaseHost 'localhost' -Environment 'Dev'

      $d.UserName | Should -Be $env:USERNAME
      $d.IsDerivable | Should -BeFalse
    }
  }

  Context 'classification overrides (forward compatibility)' {
    It 'treats an explicitly credentialed name as credentialed even on a sprint tier' {
      $name = 'dbConnectionString-ATAPUtilities-localhost-Dev-jsmith'
      $d = Get-DbConnectionStringSecretDescriptor `
        -SecretName $name `
        -DerivableTier @('Dev') `
        -CredentialedSecretName @($name)

      $d.IsDerivable | Should -BeFalse
      $d.Classification | Should -Be 'credentialed'
      $d.ConnectionString | Should -BeNullOrEmpty
    }

    It 'treats Dev as credentialed when it is removed from -DerivableTier' {
      $d = Get-DbConnectionStringSecretDescriptor -SecretName 'dbConnectionString-master-localhost-Dev-jsmith' -DerivableTier @('Exp')

      $d.IsDerivable | Should -BeFalse
      $d.ConnectionString | Should -BeNullOrEmpty
    }
  }
}
