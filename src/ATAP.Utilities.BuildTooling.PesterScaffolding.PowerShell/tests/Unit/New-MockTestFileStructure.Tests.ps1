# Load mock functions
# The function to create the mock filesystem structure is part of the production buildtooling.powershell module
#  and is auto loaded
# but when testing the a development or QA version of function, we need to load it directly.
# Development versions are loaded from the source directory
#  and QA versions are loaded from the QA server
# ToDo: switch on CI and on environment and on lifecycleStage
# This is for function development and testing during the development phase, local to a developers computer
#  dot-source the file from its source code location (relative to the location of this test file)
. Join-Path $PSScriptRoot '..' '..', 'public', 'New-MockTestFileStructure.ps1'

Describe 'Mock Filesystem Setup and Test' {

  BeforeAll {
    # Assume $global:settings are correctly populated for this environment and lifecycle stage
    $basePath = $global:settings[$global:configRootKeys['FastTempBasePathConfigRootKey']]

    # Create the mock structure
    $fsResult = New-MockTestFileStructure -BasePath $basePath

    # Store in shared scope if needed
    $script:TestMockRoot = $fsResult.TestMockRootDir
    $script:Project1Path = $fsResult.Project1Dir
    $script:Project2Path = $fsResult.Project2Dir
  }

  It 'should create the root directory' {
    Test-Path $script:TestMockRoot | Should -BeTrue
  }

  It 'should include expected project1 module files' {
    Test-Path (Join-Path $script:Project1Path 'project1.psm1') | Should -BeTrue
    Test-Path (Join-Path $script:Project1Path 'project1.psd1') | Should -BeTrue
  }

  It 'should include the ChocolateyInstall script under tools' {
    $chocoScript = Join-Path $script:Project2Path 'tools\ChocolateyInstall.ps1'
    Test-Path $chocoScript | Should -BeTrue
  }
}

