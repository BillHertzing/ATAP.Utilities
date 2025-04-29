#Requires -Module Pester

Describe 'Get-ModuleAsSymbolicLink' {

  BeforeAll {
    # Import the function from your module (ensure it's loaded in the session)
    Import-Module ATAP.Utilities.Buildtooling.Powershell -Force -Verbose
  }

  BeforeEach {
    # Set up common test data
    $ModuleName = 'TestModule'
    $ModuleVersion = '1.0.0'
    $SourcePath = 'C:\Temp\SourceModule'
    $TargetPath = 'C:\Temp\TargetModule'
    $Force = $false
  }

  It 'Should create a target directory if it does not exist' {
    Mock Test-Path { $false } -Verifiable
    Mock New-Item { 'Directory Created' } -Verifiable

    Get-ModuleAsSymbolicLink -Name $ModuleName -Version $ModuleVersion -SourcePath $SourcePath -TargetPath $TargetPath -Force:$Force

    Should -Invoke Test-Path -Times 1
    Should -Invoke New-Item -Times 2  # Once for the module, once for the version subdirectory
  }

  It 'Should not create a directory if it already exists' {
    Mock Test-Path { $true } -Verifiable
    Mock New-Item { 'Directory Exists' } -Verifiable -Times 0  # Should not be called

    Get-ModuleAsSymbolicLink -Name $ModuleName -Version $ModuleVersion -SourcePath $SourcePath -TargetPath $TargetPath -Force:$Force

    Should -Invoke Test-Path -Times 1
    Should -Not -Invoke New-Item
  }

  It 'Should create symbolic links for matching files' {
    Mock Get-ChildItem {
      [PSCustomObject]@{ Name = 'test.psm1'; FullName = "$SourcePath\test.psm1" }
    } -Verifiable

    Mock Test-Path { $false } -Verifiable
    Mock New-Item { 'SymbolicLink Created' } -Verifiable

    Get-ModuleAsSymbolicLink -Name $ModuleName -Version $ModuleVersion -SourcePath $SourcePath -TargetPath $TargetPath -Force:$Force

    Should -Invoke Get-ChildItem -Times 1
    Should -Invoke New-Item -Times 1
  }

  It 'Should copy .psd1 files instead of creating symbolic links' {
    Mock Get-ChildItem {
      [PSCustomObject]@{ Name = 'test.psd1'; FullName = "$SourcePath\test.psd1" }
    } -Verifiable

    Mock Copy-Item { 'File Copied' } -Verifiable

    Get-ModuleAsSymbolicLink -Name $ModuleName -Version $ModuleVersion -SourcePath $SourcePath -TargetPath $TargetPath -Force:$Force

    Should -Invoke Get-ChildItem -Times 1
    Should -Invoke Copy-Item -Times 1
  }

  It 'Should remove and recreate symbolic links when -Force is used' {
    Mock Test-Path { $true } -Verifiable
    Mock Remove-Item { 'SymbolicLink Removed' } -Verifiable
    Mock New-Item { 'SymbolicLink Recreated' } -Verifiable

    Get-ModuleAsSymbolicLink -Name $ModuleName -Version $ModuleVersion -SourcePath $SourcePath -TargetPath $TargetPath -Force:$true

    Should -Invoke Remove-Item -Times 1
    Should -Invoke New-Item -Times 1
  }

  AfterEach {
    # Cleanup after each test (optional)
    Remove-Mock * -ErrorAction SilentlyContinue
  }
}
