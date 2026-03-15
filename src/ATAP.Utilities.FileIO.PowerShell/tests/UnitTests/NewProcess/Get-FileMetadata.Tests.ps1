# Pester test for an individual Powershell public function in the ATAP.Utilities monorepo
# expects Pester V5

BeforeAll {

  # [The Assert framework functions for Powershell / Pester](https://github.com/nohwnd/Assert)
  # They must be installed, using (for all users) the command Install-Module -Name Assert
  # Install-Module -Name Assert -Scope AllUsers
  Import-Module -Name Assert
  # What to dot source for running a test against a "public" function in a powershell module
  #  uses the opinionated ATAP.Utilities expected directory structure for a monorepo with multiple Powershell modules
  # Tests are found in the path <RepoRootPath>/Tests/<ModuleName>, and indivudaully named as <scriptName>[stage]Tests.ps1
  # stage refers to one of Unit, Integration, UI, Performance, etc. See [TBD](TBD) for the complete list of test stages
  # Powershell script code to be tested is found in <RepoRootPath>/src/<ModuleName>/public/<scriptname.ps1>

  $moduleNameSeperator = '.'
  $sUTNameSeperator = '.'
  try {
    $ModuleBasePath = Resolve-Path $(Join-Path $PSCommandPath '..' '..' )
  }
  catch {
    $message = "In Before-All, trying to resolve the ModuleBasePath as $(Join-Path $PSCommandPath '..' '..' 'xyz') threw the exception text $($_.Exception.Message)"
    Write-PSFMessage -Level Debug -Message $message -Tag '%FunctionName%'
    # toDo catch the errors, add to 'Problems'
    Throw $message
    $skipTests = $true
  }

  # $testScriptComponentArray = $(Split-Path $PSCommandPath -Leaf) -split "\$sUTNameSeperator"


  # $sUTFileName = $($($testScriptComponentArray[0..$($testScriptComponentArray.count - 3)]) -join $sUTNameSeperator) + $sUTNameSeperator + 'ps1'

  # $sUTRelativePath =  Join-Path $ModuleBasePath 'public'

  # $sUTAbsolutePath = Resolve-Path $(Join-Path $ModuleBasePath $sUTRelativeToModulePath $sUTFileName)


  # $testScriptName = Split-Path -Leaf $PSCommandPath

  # $testScriptAbsoluteDirectoryPath = Join-Path '..' '..'

  # $sUTAbsoluteDirectory = Join-Path $ModuleBasePath 'public'

  # Resolve-Path $sUTRelativePrefix
  # $testScriptAbsolutePath = $PSCommandPath

  # # Derive the ScriptUnderTest (SUT) full path
  # # Get just the name of the SUT by removing anything matching the pattern .[stage]tests.ps1, which is the last two elements of the array
  # $sUTLeafNameComponentArray = $(Split-Path $testScriptAbsolutePath -Leaf) -split "\$sUTNameSeperator"
  # $sUTFileName = $($($sUTLeafNameComponentArray[0..$($sUTLeafNameComponentArray.count - 3)]) -join $sUTNameSeperator) + $sUTNameSeperator + 'ps1'
  # # Get the name of the module
  # $testModuleName = Split-Path -Leaf $testDirectoryAbsolutePath
  # $testModuleNameArray = $testModuleName -split "\$moduleNameSeperator"
  # $sUTModuleName = $($testModuleNameArray[0..$($testModuleNameArray.count - 2)]) -join $moduleNameSeperator
  # # Get the absolute path to the module
  # $moduleAbsolutePath = Join-Path $testDirectoryAbsolutePath $sUTRelativePrefix @(, $sUTModuleName)
  # # Get the absolute path to the SUT using the opinionated ATAP.Utilities
  # # # ToDo: add try/catch, since the Resolve-Path will fail if the given path does not exist
  # $sUTAbsolutePath = Resolve-Path $(Join-Path $moduleAbsolutePath $sUTRelativeToModulePath $sUTFileName)
  # # load the ScriptUnderTest to test into memory
  # . $sUTAbsolutePath

  $datafilePath = 'Get-FileMetadata10.TestData.yml'
  $FileMetadataHashtables = [System.Collections.Generic.List[hashtable]]::new()
  $RawMetadataFromFile = Get-Content $datafilePath -Raw | ConvertFrom-Yaml
  for ($MetadataHashtablesIndex = 0; $MetadataHashtablesIndex -lt $RawMetadataFromFile.Count; $MetadataHashtablesIndex++) {
    $MetadataHashtable = $RawMetadataFromFile[$MetadataHashtablesIndex]
    $FileMetadataHashtables.Add($MetadataHashtable)
  }
}

Describe 'ScriptOrModuleUnderTest' -ForEach @( # ToDo: figure out how to use the $sUTFileName
  @{Name            = 'GPS Longitude'
    SourceYamlFile  = 'Get-FileMetadata10.TestData.yml'
    Delegate        = [Func[PSCustomObject, bool]] { param([PSCustomObject]$o); return $o.ContainsKey('DoesNotExist')}
    ExpectedResults = 0

  }
  , @{Name          = 'GPS Latitude'
    SourceYamlFile  = 'Get-FileMetadata10.TestData.yml'
    Delegate        = [Func[PSCustomObject, bool]] { param([PSCustomObject]$o); return $o.ContainsKey('GPS Longitude') }
    ExpectedResults = 10
  }
) {
  param(
    [string] $Name
    , [string] $SourceYamlFile
    , [Func[PSCustomObject, bool]]  $Delegate
    , [string[]] $ExpectedResults
  )

  BeforeEach {
    $Results = @{}
  }

  It '<name> has the expected value' {
    # Test settings for this specific test case
    if (further -eq 'Continue') {
      Write-Host $name
    }
    if (-not $skipTests) {
    # ToDo: support additional SourceYAMLFiles. For Now, just use the $FileMetadataHashtables collection
    # $a = [Linq.Enumerable]::ToList([Linq.Enumerable]::Count([PSCustomObject[]]$FileMetadataHashtables, $delegate ))
    $a = [Linq.Enumerable]::Count([PSCustomObject[]]$FileMetadataHashtables, $delegate )
    # [Linq.Enumerable]::DistinctBy([PSCustomObject[]]$(Get-LinksFromDrafts), $delegateDistinctURL )
    # $a = [Linq.Enumerable]::Count([System.Collections.Generic.List[hashtable]]$FileMetadataHashtables, $delegate )
    Assert-Equivalent -Actual $a -Expected $ExpectedResults
    }
    else {
        Skip "Skipping <name> due to a previous exception in BeforeAll"
    }
  }
}
