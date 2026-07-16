# Requires -Version 5.0
Describe 'Set-ProGetServiceDependency' {

  BeforeAll {
    # Import the function under test
    . "$PSScriptRoot\..\Path\To\Your\Script\New-ProGetFunctions.ps1"
  }

  Context 'When INEDOPROGETSVC already depends on MSSQL$Production' {
    Mock Get-Service { @{ Name = 'INEDOPROGETSVC' } }
    Mock Get-ItemProperty {
      [PSCustomObject]@{
        DependOnService = @('MSSQL$Production')
      }
    }
    Mock Write-PSFMessage {}
    Mock ShouldProcess { $true }

    It 'Does not call sc.exe config' {
      Mock 'sc.exe' {}

      Set-ProGetServiceDependency

      Assert-MockCalled 'sc.exe' -Times 0
    }
  }

  Context 'When INEDOPROGETSVC has no existing dependency' {
    Mock Get-Service { @{ Name = 'INEDOPROGETSVC' } }
    Mock Get-ItemProperty {
      [PSCustomObject]@{
        DependOnService = @()
      }
    }
    Mock Write-PSFMessage {}
    Mock ShouldProcess { $true }
    Mock 'sc.exe' {}

    It 'Calls sc.exe config with new dependency' {
      Set-ProGetServiceDependency

      Assert-MockCalled 'sc.exe' -Times 1 -Exactly
    }
  }

  Context 'When the service does not exist' {
    Mock Get-Service { throw "Service not found" }
    Mock Write-PSFMessage {}

    It 'Throws and logs an error' {
      { Set-ProGetServiceDependency } | Should -Throw
      Assert-MockCalled Write-PSFMessage -ParameterFilter {
        $Level -eq 'Error' -and $Message -like '*does not exist*'
      }
    }
  }
}
