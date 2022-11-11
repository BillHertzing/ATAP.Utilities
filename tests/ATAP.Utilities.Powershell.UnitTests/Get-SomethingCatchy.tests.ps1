# Pester test for an individual Powershell public function in the ATAP.Utilities monorepo
# expects Pester V5

BeforeAll {

  # [The Assert framework functions for Powershell / Pester](https://github.com/nohwnd/Assert)
  # They must be installed, using (for all users) the command Install-Module -Name Assert
  Install-Module -Name Assert
  # What to dot source for running a test against a "public" function in a powershell module
  #  uses the opinionated ATAP.Utilities expected directrory structure for a monorepo with multiple Powershell modules
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

}

Describe "Testing Function $sUTFileName" -ForEach @(
  @{Name                          = 'EmptyHash'
    SourceCollections             = @(,
      @{}
    )
    ExpectedDestinationCollection = @{}
    MatchPatternRegex             = [System.Text.RegularExpressions.Regex]::new('NotNeededForThisTest')
  }
  , @{Name                        = 'SimpleIntAndString'
    SourceCollections             = @(,
      @{
        'simpleKeyForInt'    = 1
        'simpleKeyForString' = 'A'
      }
    )
    ExpectedDestinationCollection = @{
      'simpleKeyForInt'    = 1
      'simpleKeyForString' = 'A'
    }
    MatchPatternRegex             = [System.Text.RegularExpressions.Regex]::new('NotNeededForThisTest')
  }
  , @{Name                        = 'OneEmptyChildHash'
    SourceCollections             = @(,
      @{
        'ChildHash' = @{}
      }
    )
    ExpectedDestinationCollection = @{
      # Pester uses the name of the type if the hashtable is empty
      'ChildHash' = 'System.Collections.Hashtable'
    }
    MatchPatternRegex             = [System.Text.RegularExpressions.Regex]::new('NotNeededForThisTest')
  }
  , @{Name                        = 'ChildHashWithString'
    SourceCollections             = @(,
      @{
        'ChildHash' = @{
          'simpleKeyForString' = 'A'
        }
      }
    )
    ExpectedDestinationCollection = @{
      'ChildHash' = @{'simpleKeyForString' = 'A' }
    }
    MatchPatternRegex             = [System.Text.RegularExpressions.Regex]::new('NotNeededForThisTest')
  }
  , @{Name                        = 'ChildHashWithInt'
    SourceCollections             = @(,
      @{
        'ChildHash' = @{
          'simpleKeyForInt' = 'A'
        }
      }
    )
    ExpectedDestinationCollection = @{
      'ChildHash' = @{
        'simpleKeyForInt' = 'A'
      }
    }
    MatchPatternRegex             = [System.Text.RegularExpressions.Regex]::new('NotNeededForThisTest')
  }
  , @{Name                        = 'SimplePSFunctionCall'
    SourceCollections             = @(,
      @{
        'PSFunctionCall' = Join-Path $env:ProgramData 'chocolatey' 'lib'
      }
    )
    ExpectedDestinationCollection = @{
      'PSFunctionCall' = Join-Path $env:ProgramData 'chocolatey' 'lib'
    }
    MatchPatternRegex             = [System.Text.RegularExpressions.Regex]::new('NotNeededForThisTest')
  }
  , @{Name                        = 'SourceRefersToDestination'
    SourceCollections             = @(,
      @{
        'simpleKeyForString' = 'A'
        'ReferenceTo'        = '$Destination[''simpleKeyForString'']'
      }
    )
    ExpectedDestinationCollection = @{
      'simpleKeyForString' = 'A'
      'ReferenceTo'        = 'A'
    }
    MatchPatternRegex             = [System.Text.RegularExpressions.Regex]::new('destination\[\s*(["'']{0,1})(?<Earlier>.*?)\1\s*\]', [System.Text.RegularExpressions.RegexOptions]::Singleline + [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) #   $regexOptions # [regex]::new((?smi)'global:settings\[(?<Earlier>.*?)\]')
  }
  , @{Name                        = 'SourcecontainsACollectionHavingAnElementThatRefersToDestination'
    SourceCollections             = @(,
      @{
        'simpleKeyForString' = 'A'
        'ChildHash'          = @{
          'InnerReferenceTo' = '$Destination[''simpleKeyForString'']'
        }
        'OuterReferenceTo'   = '$Destination[''simpleKeyForString'']'
      }
    )
    ExpectedDestinationCollection = @{
      'simpleKeyForString' = 'A'
      'ChildHash'          = @{
        'InnerReferenceTo' = 'A'
      }
      'OuterReferenceTo'   = 'A'
    }
    MatchPatternRegex             = [System.Text.RegularExpressions.Regex]::new('destination\[\s*(["'']{0,1})(?<Earlier>.*?)\1\s*\]', [System.Text.RegularExpressions.RegexOptions]::Singleline + [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) #   $regexOptions # [regex]::new((?smi)'global:settings\[(?<Earlier>.*?)\]')
  }
  # , @{Name            = 'BuildsGlobalSettings'
  # DestinationCollection = $global:Settings
  # SourceCollections = @($global:SecurityAndSecretsSettings, $global:MachineAndNodeSettings)
  # MatchPatternRegex = [System.Text.RegularExpressions.Regex]::new('global:settings\[\s*(["'']{0,1})(?<Earlier>[^\]]*?[\]])\1\s*\]', [System.Text.RegularExpressions.RegexOptions]::Singleline + [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) #   $regexOptions # [regex]::new((?smi)'global:settings\[(?<Earlier>.*?)\]')
  # }
) {
  param(
    [string] $Name
    , [object[]] $SourceCollections
    , [System.Collections.Hashtable] $ExpectedDestinationCollection
    , [System.Text.RegularExpressions.Regex] $MatchPatternRegex
  )

  BeforeEach {
    $DestinationCollection = @{}
  }

  # It 'A test that should be true' {
  #   $true | Should -Be $true
  # }
  # It 'A test that should be false' {
  #   $false | Should -Be $true
  # }
  It "$Name has the expected destination" {
    # Test settings for this specific test case
    if ($DebugPreference -eq 'Continue') {
      write-host $name
    }

    Get-SomethingCatchy -sourceCollections $SourceCollections -destination $DestinationCollection -matchPatternRegex $MatchPatternRegex
    Assert-Equivalent -Actual $DestinationCollection -Expected $ExpectedDestinationCollection
  }
  # It 'handles simple ints and strings in one collection' {
  #   $SourceCollections = @($TestCaseSimpleIntAndString)
  #   $Destination = @{}
  #   $numKeys = $SourceCollections[0].count
  #   Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $Destination -MatchPatternRegex $MatchPatternRegex
  #   foreach ($key in $SourceCollections[0] ) {
  #     $Destination[$key] | Should -Be $TestCaseSimpleIntAndString[$key]
  #   }
  #   $Destination.count | Should -Be $numkeys
  # }
  # It 'handles an empty child hash' {
  #   $SourceCollections = @($TestCaseEmptyChildHash)
  #   $Destination = @{}
  #   $numKeys = $SourceCollections[0].count
  #   Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $Destination -MatchPatternRegex $MatchPatternRegex
  #   foreach ($key in $SourceCollections[0] ) {
  #     $Destination[$key] | Should -Be $TestCaseEmptyChildHash[$key]
  #   }
  #   $Destination.count | Should -Be $numkeys
  # }
  # It 'handles a child hash with an int value' {
  #   $SourceCollections = @($TestCaseChildHashWithInt)
  #   $Destination = @{}
  #   $numKeys = $SourceCollections[0].count
  #   Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $Destination -MatchPatternRegex $MatchPatternRegex
  #   foreach ($key in $SourceCollections[0] ) {
  #     $Destination[$key] | Should -Be $TestCaseChildHashWithInt[$key]
  #   }
  #   $Destination.count | Should -Be $numkeys
  # }
  # It 'handles a child hash with a string value' {
  #   $SourceCollections = @($TestCaseChildHashWithString)
  #   $Destination = @{}
  #   $numKeys = $SourceCollections[0].count
  #   Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $Destination -MatchPatternRegex $MatchPatternRegex
  #   foreach ($key in $SourceCollections[0] ) {
  #     $Destination[$key] | Should -Be $TestCaseChildHashWithString[$key]
  #   }
  #   $Destination.count | Should -Be $numkeys
  # }
  # It 'handles a simple PS function call in one collection' {
  #   $SourceCollections = @($TestCaseSimplePSFunctionCall)
  #   $Destination = @{}
  #   $numKeys = $SourceCollections[0].count
  #   Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $Destination -MatchPatternRegex $MatchPatternRegex
  #   foreach ($key in $SourceCollections[0] ) {
  #     $Destination[$key] | Should -Be $TestCaseSimpleIntAndString[$key]
  #   }
  #   $Destination.count | Should -Be $numkeys
  # }
  # It 'handles a deferred PS function call in one collection' {
  #   $SourceCollections = @($TestCaseDeferredPSFunctionCall)
  #   $Destination = @{}
  #   $numKeys = $SourceCollections[0].count
  #   Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $Destination -MatchPatternRegex $MatchPatternRegex
  #   foreach ($key in $SourceCollections[0] ) {
  #     $Destination[$key] | Should -Be $TestCaseSimpleIntAndString[$key]
  #   }
  #   $Destination.count | Should -Be $numkeys
  # }
  # It 'handles a deferred PS function call in a subordinate hash' {
  #   $SourceCollections = @($TestCaseDeferredPSFunctionCallInSubordinateHash)
  #   $Destination = @{}
  #   $numKeys = $SourceCollections[0].count
  #   Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $Destination -MatchPatternRegex $MatchPatternRegex
  #   foreach ($key in $SourceCollections[0] ) {
  #     $Destination[$key] | Should -Be $TestCaseDeferredPSFunctionCallInSubordinateHash[$key]
  #   }
  #   $Destination.count | Should -Be $numkeys
  # }
  # It 'handles SourceRefersToDestination for a string value' {
  #   $SourceCollections = @($TestCaseSourceRefersToDestination)
  #   $Destination = @{}
  #   $numKeys = $SourceCollections[0].count
  #   Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $Destination -MatchPatternRegex $MatchPatternRegex
  #   Write-HashIndented $Destination

  #   foreach ($key in $SourceCollections[0] ) {
  #     $Destination[$key] | Should -Be $TestCaseSourceRefersToDestination[$key]
  #   }
  #   $Destination.count | Should -Be $numkeys
  # }
  # It 'produces Global:Settings' {
  #   $SourceCollections = @($global:SecurityAndSecretsSettings, $global:MachineAndNodeSettings)
  #   $Destination = @{}
  #   #$numKeys = $SourceCollections[0].count
  #   Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $global:settings -MatchPatternRegex $MatchPatternRegex
  #   # foreach ($key in $SourceCollections[0] ) {
  #   #   $Destination[$key] | Should -Be $TestCaseDeferredPSFunctionCallInSubordinateHash[$key]
  #   # }
  #   # $Destination.count | Should -Be $numkeys
  #   Write-HashIndented $Destination
  # }

}
