# Pester test for an individual Powershell public function in the ATAP.Utilities monorepor

# What to dot source for running a test against a "public" function in a powershell module
#  uses the opinionated ATAP.Utilities expected directrory structure for a monorepo with multiple Powershell modules
$moduleNameSeperator = '.'
$functionSUTNameSeperator = '.'
$srcSUTRelativePrefix = Join-Path '..' '..' 'src'
$srcSUTRelativePathSuffix = 'public'

# A priori, all extensions are .ps1. throw away the extension in the step below, it will get added back later
$functionSUTPath = Split-Path -LeafBase $MyInvocation.MyCommand.Path
$functionSUTPathArray = $functionSUTPath -split "\$functionSUTNameSeperator"
$functionSUTName = $functionSUTPathArray[0..$($functionSUTPathArray.count - 2)]
$functionSUTPath = $($functionSUTName -join $functionSUTNameSeperator) + $functionSUTNameSeperator + 'ps1'
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleName = Split-Path -Leaf $scriptDirectory
$moduleNameArray = $moduleName -split "\$moduleNameSeperator"
$srcModuleName = $($moduleNameArray[0..$($moduleNameArray.count - 2)]) -join $moduleNameSeperator
$srcModuleRelativePath = Join-Path $srcSUTRelativePrefix $srcModuleName
# The VSC powershell extension apparently wants a full path
# ToDo: add try/catch, since the Resolve-Path will fail if the given path does not exist
$srcModuleRelativePath = Resolve-Path $srcModuleRelativePath
$functionSUTPathSUT = Join-Path $srcModuleRelativePath $srcSUTRelativePathSuffix $functionSUTPath
# load the script to test into memory
. $functionSUTPathSUT



$TestCaseSimpleIntAndString = @{
  'simpleKeyForInt'    = 1
  'simpleKeyForString' = 'A'
}

$TestCaseEmptyChildHash = @{
  'ChildHash' = @{}
}

$TestCaseChildHashWithInt = @{
  'ChildHash' = @{
    'simpleKeyForInt' = 1
  }
}

$TestCaseChildHashWithString = @{
  'ChildHash' = @{
    'simpleKeyForString' = 'A'
  }
}

$TestCaseSimplePSFunctionCall = @{
  'PSFunctionCall' = Join-Path $env:ProgramData 'chocolatey' 'lib'
}

$TestCaseDeferredPSFunctionCall = @{
  'PSDeferredFunctionCall' = 'Join-Path "path001" "path002"'
}

$TestCaseDeferredPSFunctionCallInSubordinateHash = @{
  'ChildHash'              = @{
    'PSDeferredFunctionCall' = 'Join-Path "path003" "path004"'
  }
  'PSDeferredFunctionCall' = 'Join-Path "path001" "path002"'
}

$TestCaseSourceRefersToDestination = @{
  'simpleKeyForString' = 'A'
  'ReferenceTo'        = '$Destination[''simpleKeyForString'']'
}

$TestSettings3 = @{

  aaa  = '123'
  bbb  = '234'
  aba  = '$global:settings["aaa"]'
  abb  = '$global:settings["aaa"] + $global:settings["bbb"]'
  HCC  = @{C1 = 'constant' }
  HD1  = @{kd1 = '$global:settings["aaa"]' }
  Ary1 = @(123, 456)
  Ary2 = @('123', '456')
  Ary3 = @('$global:settings["aaa"]', '$global:settings["bbb"]')
  # eee = '$global:settings["mmm"]["C1"]'
  # fff = '$global:settings["HD1"]["kd1"]'

}
$TestSettings2 = @{
  ZZZ = 'some1'
  YYY = '2some'
  NNN = '$global:settings["aaa"]'
}

$matchPatternRegex = [System.Text.RegularExpressions.Regex]::new('global:settings\[\s*(["'']{0,1})(?<Earlier>.*?)\1\s*\]', [System.Text.RegularExpressions.RegexOptions]::Singleline + [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) #   $regexOptions # [regex]::new((?smi)'global:settings\[(?<Earlier>.*?)\]')
# $SourceCollections = @($TestSettings1, $TestSettings2) # @($global:SecurityAndSecretsSettings, $global:MachineAndNodeSettings) #
$numkeys = 0
foreach ($testcollection in $SourceCollections) { $numkeys += $testcollection.keys.count }
$Destination = @{}

Describe "Testing Function $functionSUTName" -ForEach @(
  @{Name              = 'EmptyHash'
    SourceCollections = @(,
      @{}
    )
  }
  , @{Name            = 'SimpleIntAndString'
    SourceCollections = @(,
      @{
        'simpleKeyForInt'    = 1
        'simpleKeyForString' = 'A'
      }
    )
  }
  , @{Name            = 'OneEmtpryChildHash'
    SourceCollections = @(,
      @{
        'ChildHash' = @{}
      }
    )
  }
  , @{Name            = 'ChildHashWithString'
    SourceCollections = @(,
      @{
        'ChildHash' = @{
          'simpleKeyForString' = 'A'
        }
      }
    )
  }
  , @{Name            = 'SourceRefersToDestination'
    SourceCollections = @(,
      @{
        'simpleKeyForString' = 'A'
        'ReferenceTo'        = '$Destination[''simpleKeyForString'']'
      }
    )
  }
) {
  param(
    [string] $Name
    , [object[]] $SourceCollections
  )
  # It 'A test that should be true' {
  #   $true | Should -Be $true
  # }
  # It 'A test that should be false' {
  #   $false | Should -Be $true
  # }
  It '<Name> has the correct number of destination keys' {
    $numkeys = 0
    foreach ($collection in  $SourceCollections) {
      $numKeys += $collection.count
    }
    $Destination = @{}
    Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $Destination -MatchPatternRegex $MatchPatternRegex
    $Destination.count | Should -Be $numKeys
  }
  It '<Name> has the correct root-level destination keys' {
    # Test settings for this specific test case
    $Destination = @{}
    Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $Destination -MatchPatternRegex $MatchPatternRegex
    foreach ($collection in  $SourceCollections) {
      foreach ($key in $collection) {
        $Destination[$key] | Should -Be $collection[$key]
      }
    }
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
