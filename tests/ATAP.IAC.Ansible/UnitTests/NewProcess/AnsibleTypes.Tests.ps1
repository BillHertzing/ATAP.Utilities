# expects Pester V5

BeforeAll {

  # [The Assert framework functions for Powershell / Pester](https://github.com/nohwnd/Assert)
  # They must be installed, using (for all users) the command Install-Module -Name Assert
  Install-Module -Name Assert

  # ToDo: Move strings to a ConfigRootKey
  $srcName = 'src'
  $testsName = 'tests'
  $moduleNameSeperator = '.'
  $sUTNameSeperator = '.'

  # ToDo: move this to a buildtooling function

  function Find-SourceAndTestDirectory {
    param(
      [string]$InitialDirectory,
      [string]$SrcName,
      [string]$TestsName
    )
    $CommonDirectory = $InitialDirectory
    $leafNames = @()
    while ($CommonDirectory -ne $null) {
      # ToDo: protect edge case - if there is a directory 'src' below the tests directory..
      $srcDir = Join-Path -Path $CommonDirectory -ChildPath $SrcName
      if (Test-Path -Path $srcDir -PathType Container) {
        # Is there both a 'src' and a 'tests' directory?
        $testDir = Join-Path -Path $CommonDirectory -ChildPath $TestsName
        if (Test-Path -Path $testDir -PathType Container) {
          # Yes
          # what is the name of the subdirectory under 'test's that matches the initial directory?

          # does the same leaf appear in both source and tests,
          return @{
            ModuleName = $moduleName
            SourceDirectory     = Join-Path $CommonDirectory $SrcName $ModuleName
            TestsDirectory   = Join-Path $CommonDirectory $TestsName $ModuleName
          }
        }
        else {
          # ToDo: Logging
          throw 'A directory matching the module name must be found in both src and test directories'
        }
      }
      $CommonDirectory = Split-Path -Path $CommonDirectory -Parent
      $leafNames +=  Split-Path $CommonDirectory -Leaf
      $moduleName = $leafNames[1]
    }
    # ToDo: Logging
    throw 'A directory matching src was not found'
  }

  # ToDo: move this to a buildtooling function
  function Search-FilesBySubdirectories {
    param(
      [string]$BasePath,
      [string[]]$Subdirectories,
      [string]$FileNameBase,
      [string[]]$PotentialSuffixes
    )
    $result = @()
    foreach ($subdir in $Subdirectories) {
      $fullPath = Join-Path -Path $BasePath -ChildPath $subdir
      foreach ($suffix in $PotentialSuffixes) {
        $fileName = $FileNameBase + $suffix
        $filePath = Join-Path -Path $fullPath -ChildPath $fileName
        if (Test-Path -Path $filePath -PathType Leaf) {
          $result += $filePath
        }
      }
    }
    return $result
  }

  # What to dot source for running a test against a "public" function in a powershell module
  #  uses the opinionated ATAP.Utilities expected directory structure for a monorepo with multiple Powershell modules
  # Tests are found in the path <RepoRootPath>/Tests/<ModuleName>, and indivudaully named as <scriptName>[stage]Tests.ps1
  # stage refers to one of Unit, Integration, UI, Performance, etc. See [TBD](TBD) for the complete list of test stages
  # Powershell script code to be tested is found in <RepoRootPath>/src/<ModuleName>/public/<scriptname.ps1>
  # Custom assemblies created to be tested is found in <RepoRootPath>/<ModuleName>/<assemblyname.dll>

  #  find the script or the .dll to be tested, based on the name of this test file

  # if $env:CI is true, or if $env:Environment is set to 'QualityAssurance' or 'Production'
  # ToDo: Move strings to a ConfigRootKey or Enumeration

  if ($env:CI -eq $true -or $env:Environment -eq 'QualityAssurance' -or $env:Environment -eq 'Production') {
    # The full module / package is being tested, tests are found under the checked out module direcotry
    throw 'not implemented'
  }
  else {
    # when the test script is run from a development IDE environment
    # the location of the sUT is 'opinionated'
    $testDirectoryAbsolutePath = $PSScriptRoot
    $testScriptAbsolutePath = $PSCommandPath
    $testScriptName = Split-Path $testScriptAbsolutePath -Leaf
    $testScriptNameArray = $testScriptName -split "\$moduleNameSeperator"
    # the name of the modules under 'test' and the name of the module under 'src' must match exactly
    # the name of the module being tested is the leaf of the src and tests path that belong to the PSScriptRoot
    # The following subroutine uses the current direcotry as the basis for finding the module name
    $commonParent = Find-SourceAndTestDirectory -InitialDirectory $(Get-Location) -SrcName $srcName -TestsName $testsName
    # remove  the last two elements of the array ('tests' and 'ps1') and rejoin the rest
    # Opinionated: the name of the script or custom assembly being tested matches the base name of the script
    # sUT means 'Script Under Test'. and it can also apply to 'Assembly Under Test' when a test matches a custom assembly name
    $sUTModuleBaseDirectory = $commonParent.SourceDirectory
    $sUTModuleName = $commonParent.ModuleName
    # ToDo: The number 3 is opinionated
    $sUTBaseName = $($testScriptNameArray[0..$($testScriptNameArray.count - 3)]) -join $moduleNameSeperator
    # ToDo: move strings to a ConfigRootKey
    $sUTRelativeToModuleBasePaths = @('.\', '.\public', '.\private')
    # ToDo: move strings to a ConfigRootKey
    $sUTPotentialSuffixs = @('.ps1', '.dll')
    # search the sUT potential paths to find a matching script or assembly
    $foundFiles = Search-FilesBySubdirectories -BasePath $sUTModuleBaseDirectory -Subdirectories $sUTRelativeToModuleBasePaths -FileNameBase $sUTBaseName -PotentialSuffixes $sUTPotentialSuffixs
    switch ($foundFiles.count) {
      0 {
        #ToDo: logging
        throw ('no matching script or assembly found')
      }
      1 {
        # exactly one file found. Could be either a script or an assembly. Use the file extension to determine which
        $sUTAbsolutePath = Get-ChildItem -Path $foundFiles[0]
        # ToDo: move string to global
        if ($sUTAbsolutePath.Extension -eq 'ps1') {
          # load the ScriptUnderTest to test into memory
          # will not work if loading the script causes it to output stuff or otherwise take action
          . $sUTAbsolutePath.FullName
        }
        # ToDo: move string to global
        elseif ($sUTAbsolutePath.Extension -eq 'dll') {
          # load the AssemblyUnderTest to test into memory
          # Load the custom DLL
          Add-Type -Path $sUTAbsolutePath.FullName
          # ToDo: investigate dependnet assemblies - do they need to be explicitly loaded? OR  just ones not in GAC or PSModulePath?
          # add references to external assemblies. Ensure the assemblies referenced are compatable with the current default DotNet framework
          # reference the YamlDotNet.dll assembly found in the parent directory. Paent should be the module's main packge direcotry, a peer of the .psm1 and .psd1 files.
          # This allows access to the YamlDotNet library functions without the need to install it via the Powershell Gallery.
          # NOTE: the YamlDotNet.dll assembly must be compatable with the current default.Net framework version installed on the system
          # $referencedAssemblies = @(
          #   $yamlDotNetAssemblyPath
          #   'System.Collections.dll'
          # )
          #   $dependentAssemblyPath = join-path $PSScriptRoot "YamlDotNet.dll"
          #   #Add-Type -Path $dependentAssemblyPath

        }
      }
      default {
        #ToDo: logging
        throw ('multiple matching files not yet supported')
      }
    }
  }

}

Describe 'RegistrySettingsArgument Tests' {
  It 'Can create an instance of RegistrySettingsArgument' {
    $argument = [ATAP.Utilities.Ansible.RegistrySettingsArgument]::new()
    $argument | Should -Not -BeNull
  }

  It 'Can set and get properties of RegistrySettingsArgument' {
    $argument = [ATAP.Utilities.Ansible.RegistrySettingsArgument]::new()

    $argument.Purpose = 'TestPurpose'
    $argument.Data = 'TestData'
    $argument.Type = 'TestType'
    $argument.Path = 'TestPath'

    $argument.Purpose | Should -BeExactly 'TestPurpose'
    $argument.Data | Should -BeExactly 'TestData'
    $argument.Type | Should -BeExactly 'TestType'
    $argument.Path | Should -BeExactly 'TestPath'
  }

  It 'Can convert RegistrySettingsArgument to YAML and back' {
    $originalArgument = [ATAP.Utilities.Ansible.RegistrySettingsArgument]::new()
    $originalArgument.Purpose = 'TestPurpose'
    $originalArgument.Data = 'TestData'
    $originalArgument.Type = 'TestType'
    $originalArgument.Path = 'TestPath'

    $yaml = $originalArgument.ConvertToYaml()
    $convertedArgument = [ATAP.Utilities.Ansible.RegistrySettingsArgument]::ConvertFromYaml($yaml)

    $convertedArgument.Purpose | Should -BeExactly $originalArgument.Purpose
    $convertedArgument.Data | Should -BeExactly $originalArgument.Data
    $convertedArgument.Type | Should -BeExactly $originalArgument.Type
    $convertedArgument.Path | Should -BeExactly $originalArgument.Path
  }
}

Describe 'RegistrySettingsArgument Tests' {
  It 'Converts to YAML and back correctly' {
    $originalArgument = [RegistrySettingsArgument]::Create('Purpose', 'Data', 'Type', 'Path')
    $yamlContent = $originalArgument.ConvertToYaml()
    $convertedArgument = $originalArgument.ConvertFromYaml($yamlContent)

    # Assert properties match
    $convertedArgument.Purpose | Should Be $originalArgument.Purpose
    $convertedArgument.Data | Should Be $originalArgument.Data
    $convertedArgument.Type | Should Be $originalArgument.Type
    $convertedArgument.Path | Should Be $originalArgument.Path
  }
}

# Describe block for ChocolateyPackageArguments
Describe 'ChocolateyPackageArguments Tests' {
  It 'Converts to YAML and back correctly' {
    $originalArgument = [ChocolateyPackageArguments]::new('PackageName')
    $yamlContent = $originalArgument.ConvertToYaml()
    $convertedArgument = $originalArgument.ConvertFromYaml($yamlContent)

    # Assert properties match
    $convertedArgument.Name | Should Be $originalArgument.Name
  }
}

# Describe block for AnsibleScriptBlock
Describe 'AnsibleScriptBlock Tests' {
  It 'Converts to YAML correctly' {
    $scriptBlock = [AnsibleScriptBlock]::new([AnsibleScriptBlockKinds]::ChocolateyPackages, @())
    $yamlContent = $scriptBlock.ConvertToYaml()

    # Assert YAML content is not empty
    $yamlContent | Should Not BeNullOrEmpty
  }
}

# Describe block for Play
Describe 'Play Tests' {
  It 'Converts to YAML correctly' {
    $play = [Play]::new()
    $play.Name = 'Sample Play'
    $play.AnsibleScriptBlocks = @()
    $yamlContent = $play.ConvertToYaml()

    # Assert YAML content is not empty
    $yamlContent | Should Not BeNullOrEmpty
  }
}

# Describe block for AnsibleRole
Describe 'AnsibleRole Tests' {
  It 'Converts to YAML correctly' {
    $role = [AnsibleRole]::new('Sample Role', [AnsibleMeta]::new(), [AnsibleTask]::new())
    $yamlContent = $role.ConvertToYaml()

    # Assert YAML content is not empty
    $yamlContent | Should Not BeNullOrEmpty
  }
}






