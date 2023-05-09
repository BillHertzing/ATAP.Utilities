# expects Pester V5

	BeforeAll {

  # [The Assert framework functions for Powershell / Pester](https://github.com/nohwnd/Assert)
  # They must be installed, using (for all users) the command Install-Module -Name Assert
  Install-Module -Name Assert
  # What to dot source for running a test against a "public" function in a powershell module
  #  uses the opinionated ATAP.Utilities expected directory structure for a monorepo with multiple Powershell modules
  # Tests are found in the path <RepoRootPath>/Tests/<ModuleName>, and indivudaully named as <scriptName>[stage]Tests.ps1
  # stage refers to one of Unit, Integration, UI, Performance, etc. See [TBD](TBD) for the complete list of test stages
  # Powershell script code to be tested is found in <RepoRootPath>/src/<ModuleName>/public/<scriptname.ps1>

  $moduleNameSeperator = '.'
  $sUTNameSeperator = '.'
  $sUTRelativePrefix = Join-Path '..' '..' 'src'
  $sUTRelativeToModulePath = 'public'

  $testDirectoryAbsolutePath = $PSScriptRoot
  $testScriptAbsolutePath = $PSCommandPath

  # Derive the ScriptUnderTest (SUT) full path
  # Get just the name of the SUT by removing anything matching the pattern .[stage]tests.ps1, which is the last two elements of the array
  $sUTLeafNameComponentArray = $(Split-Path $testScriptAbsolutePath -Leaf) -split "\$sUTNameSeperator"
  $sUTFileName = $($($sUTLeafNameComponentArray[0..$($sUTLeafNameComponentArray.count - 3)]) -join $sUTNameSeperator) + $sUTNameSeperator + 'ps1'
  # Get the name of the module
  $testModuleName = Split-Path -Leaf $testDirectoryAbsolutePath
  $testModuleNameArray = $testModuleName -split "\$moduleNameSeperator"
  $sUTModuleName = $($testModuleNameArray[0..$($testModuleNameArray.count - 2)]) -join $moduleNameSeperator
  # Get the absolute path to the module
  $moduleAbsolutePath = Join-Path $testDirectoryAbsolutePath $sUTRelativePrefix @(, $sUTModuleName)
  # Get the absolute path to the SUT using the opinionated ATAP.Utilities
  # # ToDo: add try/catch, since the Resolve-Path will fail if the given path does not exist
  $sUTAbsolutePath = Resolve-Path $(Join-Path $moduleAbsolutePath $sUTRelativeToModulePath $sUTFileName)
  # load the ScriptUnderTest to test into memory
  . $sUTAbsolutePath
  
  $dataset = @(@{Name                          = 'EmptyHash'
    SourceCollections             = @(,
      @{}
    )
    ExpectedDestinationCollection = @{}
    MatchPatternRegex             = [System.Text.RegularExpressions.Regex]::new('NotNeededForThisTest')

  })
	}
  
    Describe "ScriptOrModuleUnderTest" -ForEach $dataset
	{
  param(
    [string] $Name
    , [object[]] $SourceCollections
    , [System.Collections.Hashtable] $ExpectedDestinationCollection
    , [System.Text.RegularExpressions.Regex] $MatchPatternRegex
  )

  BeforeEach {
    $DestinationCollection = @{}
  }

  It '<name> has the expected destination' {
    # Test settings for this specific test case
    if ($DebugPreference -eq 'Continue') {
      Write-Host $name
    }
    Get-CollectionTraverseEvaluate -sourceCollections $SourceCollections -destination $DestinationCollection -matchPatternRegex $MatchPatternRegex
    Assert-Equivalent -Actual $DestinationCollection -Expected $ExpectedDestinationCollection
  }
}


