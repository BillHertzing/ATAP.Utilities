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


# Test settings for this specific test case

$TestSettings1 = @{

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
$SourceCollections = @($TestSettings1, $TestSettings2) # @($global:SecurityAndSecretsSettings, $global:MachineAndNodeSettings) #
$numkeys = 0
foreach ($testcollection in $SourceCollections) { $numkeys += $testcollection.keys.count }
$global:settings = @{}

Describe "$functionSUTName Function" {
  # It 'A test that should be true' {
  #   $true | Should -Be $true
  # }
  # It 'A test that should be false' {
  #   $false | Should -Be $true
  # }

  It 'has the correect number of keys' {
    Get-SomethingCatchy -SourceCollections $SourceCollections -Destination $global:settings -MatchPatternRegex $MatchPatternRegex
    $global:settings.count | Should -Be $numkeys
  }
}
