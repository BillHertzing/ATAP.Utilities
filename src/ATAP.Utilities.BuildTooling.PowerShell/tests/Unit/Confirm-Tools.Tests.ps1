# Import the module containing the Get-CoreInfo function

Describe 'Confirm-Tools' {
  BeforeAll {
    $message = 'Starting BeforeAll in Confirm-Tools.tests.ps1'
    Write-PSFMessage -Level Debug -Message $message -Tag 'Trace', 'Tests'
    # Mock Get-ChildItem for the runtimes
    Mock -CommandName Get-ChildItem -MockWith {
      [PSCustomObject]@{ Name = '5.0.0' }
    }

    # Mock BIOS serial number
    $global:bios = [PSCustomObject]@{ SerialNumber = '12345' }
  }

  It 'Function exists' {
    Get-Command -Name 'Confirm-Tools' | Should -Not -BeNullOrEmpty
  }

  It 'Should not throw an error if all tools are present' {
    { Confirm-Tools } | Should -Not -Throw
  }
}
