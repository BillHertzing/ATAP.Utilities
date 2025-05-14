
# Import the module containing the Get-CoreInfo function

Describe 'Get-CoreInfo' {
  BeforeAll {
    $message = 'Starting BeforeAll in Get-CoreInfo.tests.ps1'
    Write-PSFMessage -Level Debug -Message $message -Tag 'Trace', 'Tests'

    $message = "cwd = ${pwd}; PSCommandPath = $PSCommandPath "
    Write-PSFMessage -Level Debug -Message $message -Tag 'Trace', 'Tests'
    function Get-ModuleBaseDirectory {
      param (
        [string] $initialDirectory = [System.IO.DirectoryInfo]::new((Get-Location).Path),
        [string] $sourceName = 'public',
        [string] $commonTestsDirectoryName = 'tests'
      )
      $currentDir = $initialDirectory
      $commonParentDirectory = $null
      while ( $null -ne $currentDir) {
        # Look for peer $testsName and $sourceName directories
        if ((Test-Path -Path $(Join-Path $currentDir $sourceName)) -and (Test-Path -Path $(Join-Path $currentDir $commonTestsDirectoryName))) {
          $commonParentDirectory = $currentDir
          break
        } else {
          #move up the directory tree
          $currentDir = (Get-Item -Path $currentDir).Parent
        }
      }
      if ( $null -eq $commonParentDirectory) {
        $message = "searching upward from $initialDirectory found no parent having both $sourceName and $commonTestsDirectoryName"
        Write-PSFMessage -Level Error -Message $message
        throw $message
      }
      # $currentdir is the path to the source of the module having this test
      $message = "DevelopmentModulePath = $currentDir"
      Write-PSFMessage -Level Debug -Message $message -Tag 'Trace', 'Tests'
      # return the current directory
      $currentdir
    }
    # Decide the place from which to load the module
    # 1) The module is in prerelease;
    # 1) the module path is provided when the by the developer

    # the module under development may be prerelease, so must use absolute path
    $modulePath = Get-ModuleBaseDirectory
    $message = "DevelopmentModulePath = $modulePath"
    Write-PSFMessage -Level Debug -Message $message -Tag 'Trace', 'Tests'
    Import-Module -Name $modulePath

    # Mock the dotnet --info command
    Mock -CommandName dotnet -MockWith {
      @'
.NET SDK (reflecting any global.json):
 Version:   5.0.100
 Commit:    d3cbfca

Runtime Environment:
 OS Name:     Windows
 OS Version:  10.0.19042
 OS Platform: Windows
 RID:         win10-x64
 Base Path:   C:\Program Files\dotnet\sdk\5.0.100\

Host (useful for support):
  Version: 5.0.0
  Commit:  cf258a14b7

.NET Core runtimes installed:
  Microsoft.NETCore.App 5.0.0 [C:\Program Files\dotnet\shared\Microsoft.NETCore.App]
'@
    }

    # Mock Get-ChildItem for the runtimes
    Mock -CommandName Get-ChildItem -MockWith {
      [PSCustomObject]@{ Name = '5.0.0' }
    }

    # Mock BIOS serial number
    $global:bios = [PSCustomObject]@{ SerialNumber = '12345' }
  }

  It 'Function exists' {
    Get-Command -Name Get-CoreInfo | Should -Not -BeNullOrEmpty
  }

  It 'Throws error when DotNet runtime or SDK is not installed' {
    Mock -CommandName Test-Path -MockWith { $false }
    { Get-CoreInfo } | Should -Throw -ErrorId 'DotNetRuntimeOrSDKNotInstalled'
  }

  It 'Retrieves .NET SDK version' {
    $result = Get-CoreInfo
    $result.DotNetSDKVersion | Should -Be '5.0.100'
  }

  It 'Retrieves .NET Core SDK version' {
    $result = Get-CoreInfo
    $result.DotNetCoreSDKVersion | Should -Be '5.0.100'
  }

  It 'Retrieves OS version' {
    $result = Get-CoreInfo
    $result.OSVersion | Should -Be '10.0.19042'
  }

  It 'Retrieves OS name' {
    $result = Get-CoreInfo
    $result.OSName | Should -Be 'Windows'
  }

  It 'Retrieves OS platform' {
    $result = Get-CoreInfo
    $result.OSPlatform | Should -Be 'Windows'
  }

  It 'Retrieves RID' {
    $result = Get-CoreInfo
    $result.RID | Should -Be 'win10-x64'
  }

  It 'Retrieves BIOS serial number' {
    $result = Get-CoreInfo
    $result.BIOSSerial | Should -Be '12345'
  }
}
