Describe 'Get Files From Repository' -Tag 'UnitTests' {

  BeforeAll {
    # Assume $global:settings are correctly populated for this environment and lifecycle stage
    # Assume the buildtooling functions found in ATAP.Utilities.BuildTooling.psm1 are loaded (or can be autoloaded).
    # Set Pester configuration
    $
    # Possible module location search path is set by $ENV:PSModulePath, which is set in profile
    # The function that finds all applicable PesterConfiguration.psd1 files, and merges them,

    # The function to create the mock filesystem structure is part of the production buildtooling.powershell module
    #  and can be auto loaded
    # ToDo: switch on CI and on environment and on lifecycleStage
    # Load the function to be tested
    $sourcePath = Get-SourceFilePath -TestFilePath $MyInvocation.MyCommand.Path
    . $sourcePath
    #    . $(Join-Path $global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']] 'whertzing' 'GitHub', 'ATAP.Utilities', 'src', 'ATAP.Utilities.BuildTooling.PowerShell', 'public', 'New-MockTestFileStructure.ps1')

    # load the function to be tested


    $basePath = $global:settings[$global:configRootKeys['FastTempBasePathConfigRootKey']]

    # Create the mock structure
    $fsResult = New-MockTestFileStructure -BasePath $basePath

    # Store in shared scope if needed
    $script:TestMockRoot = $fsResult.TestMockRootDir
    $script:Project1Path = $fsResult.Project1Dir
    $script:Project2Path = $fsResult.Project2Dir

  }

  It 'should return the correct number of files' {
    $results = Get-FilesFromRepository -repoPath $script:TestMockRoot -targetExtensions @('.cs', '.ps1', '.ts', '.js', '.md', '.json', '.jsonc', '.xml', '.yaml', '.yml', '.txt') -excludedDirs @('_generated', 'bin', 'obj')
    $($results.ToBeProcessed).count | Should Be 2
    $($results.LongFiles).count | Should Be 0
  }


}
