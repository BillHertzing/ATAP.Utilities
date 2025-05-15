# expects Pester V5

using namespace ATAP.IAC.Ansible

BeforeAll {

  # [The Assert framework functions for Powershell / Pester](https://github.com/nohwnd/Assert)
  # They must be installed, using (for all users) the command Install-Module -Name Assert
  Install-Module -Name Assert -Force

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
    while ($null -ne $CommonDirectory ) {
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
            ModuleName      = $moduleName
            SourceDirectory = Join-Path $CommonDirectory $SrcName $ModuleName
            TestsDirectory  = Join-Path $CommonDirectory $TestsName $ModuleName
          }
        } else {
          # ToDo: Logging
          throw 'A directory matching the module name must be found in both src and test directories'
        }
      }
      $CommonDirectory = Split-Path -Path $CommonDirectory -Parent
      $leafNames += Split-Path $CommonDirectory -Leaf
      $moduleName = $leafNames[1]
    }
    # ToDo: Logging
    throw 'A directory matching src was not found'
  }

  # ToDo: move this to a buildtooling function
  function Search-FilesBySubdirectories {
    [OutputType([string[]])]
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
    return , $result
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
  } else {
    # when the test script is run from a development IDE environment
    # the location of the sUT is 'opinionated'
    $testDirectoryAbsolutePath = $PSScriptRoot
    $testScriptAbsolutePath = $PSCommandPath
    $testScriptName = Split-Path $testScriptAbsolutePath -Leaf
    $testScriptNameArray = $testScriptName -split "\$moduleNameSeperator"
    # the name of the modules under 'test' and the name of the module under 'src' must match exactly
    # the name of the module being tested is the leaf of the src and tests path that belong to the PSScriptRoot
    # The following subroutine uses the current directory as the basis for finding the module name
    $commonParent = Find-SourceAndTestDirectory -InitialDirectory $(Get-Location) -SrcName $srcName -TestsName $testsName
    # remove  the last two elements of the array ('tests' and 'ps1') and rejoin the rest
    # Opinionated: the name of the script or custom assembly being tested matches the base name of the script
    # sUT means 'Script Under Test'. and it can also apply to 'Assembly Under Test' when a test matches a custom assembly name
    $sUTModuleBaseDirectory = $commonParent.SourceDirectory
    $sUTModuleName = $commonParent.ModuleName
    # ToDo: The number 3 is opinionated
    $sUTBaseName = $($testScriptNameArray[0..$($testScriptNameArray.count - 3)]) -join $moduleNameSeperator
    # ToDo: move strings to a ConfigRootKey
    $sUTRelativeToModuleBasePaths = @('.', 'public', 'private')
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
        $sUTAbsolutePath = Get-ChildItem -Path $foundFiles
        # ToDo: move string to global
        if ($sUTAbsolutePath.Extension -eq '.ps1') {
          # load the ScriptUnderTest to test into memory
          # will not work if loading the script causes it to output stuff or otherwise take action
          . $sUTAbsolutePath.FullName
        }
        # ToDo: move string to global
        elseif ($sUTAbsolutePath.Extension -eq '.dll') {
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

Describe 'Testing AnsiblePlayBlockRegistrySettings class' {

  It 'Should create an instance of AnsiblePlayBlockRegistrySettings' {
    $obj = [ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings]::new('testPurpose', 'testName', 'testPath', 'testType', 'testValue')
    $obj | Should -Not -BeNullOrEmpty
    $obj.Purpose | Should -BeExactly 'testPurpose'
    $obj.Name | Should -BeExactly 'testName'
    $obj.Path | Should -BeExactly 'testPath'
    $obj.Type | Should -BeExactly 'testType'
    $obj.Value | Should -BeExactly 'testValue'
  }

  It 'Should validate properties of AnsiblePlayBlockRegistrySettings' {
    $obj = [ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings]::new('testPurpose', 'testName', 'testPath', 'testType', 'testValue')
    $obj.Purpose = 'newPurpose'
    $obj.Purpose | Should -BeExactly 'newPurpose'
    $obj.Name = 'newName'
    $obj.Name | Should -BeExactly 'newName'
    $obj.Path = 'newPath'
    $obj.Path | Should -BeExactly 'newPath'
    $obj.Type = 'newType'
    $obj.Type | Should -BeExactly 'newType'
    $obj.Value = 'newValue'
    $obj.Value | Should -BeExactly 'newValue'
  }
  It 'Should convert AnsiblePlayBlockRegistrySettings to YAML and back' {
    $obj = [ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings]::new('testPurpose', 'testName', 'testPath', 'testType', 'testValue')

    # Convert to YAML
    $yamlString = ConvertTo-Yaml $obj
    $yamlString | Should -Not -BeNullOrEmpty

    # Convert back to object
    $newObj = ConvertFrom-Yaml $yamlString
    $newObj | Should -Not -BeNullOrEmpty
    $newObj.Purpose | Should -BeExactly 'testPurpose'
    $newObj.Name | Should -BeExactly 'testName'
    $newObj.Path | Should -BeExactly 'testPath'
    $newObj.Type | Should -BeExactly 'testType'
    $newObj.Value | Should -BeExactly 'testValue'
  }
  Describe 'Testing AnsiblePlayBlockChocolateyPackages class with YAML conversions' {
    It 'Should create AnsiblePlayBlockChocolateyPackages object via constructor' {
      $name = 'testName'
      $version = 'testVersion'
      $prerelease = $false
      $obj = [ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages]::new($name, $version, $prerelease)

      $obj.Name | Should -BeExactly $name
      $obj.Version | Should -BeExactly $version
      $obj.Prerelease | Should -Be $prerelease
    }
    It 'Should validate properties of AnsiblePlayBlockChocolateyPackages' {
      $obj = [ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages]::new('testName', 'testVersion', $false)
      $obj.Name = 'newName'
      $obj.Name | Should -BeExactly 'newName'
      $obj.Version = 'newVersion'
      $obj.Version | Should -BeExactly 'newVersion'
      $obj.Prerelease = $true
      $obj.Prerelease | Should -Be $true
    }

    It 'Should convert AnsiblePlayBlockChocolateyPackages to YAML and back' {
      $obj = [ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages]::new('testName', 'testVersion', $false)

      # Convert to YAML
      $yamlString = ConvertTo-Yaml $obj
      $yamlString | Should -Not -BeNullOrEmpty

      # Convert back to object
      $newObj = ConvertFrom-Yaml $yamlString
      $newObj | Should -Not -BeNullOrEmpty
      $newObj.Name | Should -BeExactly 'testName'
      $newObj.Version | Should -BeExactly 'testVersion'
      $newObj.Prerelease | Should -Be $false
    }
  }
  Describe 'Testing AnsiblePlay class with AnsiblePlayBlockChocolateyPackages' {
    It 'Should create AnsiblePlay object' {
      $name = 'PlayName'
      $kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages
      $items = @()

      $obj = [ATAP.IAC.Ansible.AnsiblePlay]::new($name, $kind, $items)

      $obj.Name | Should -BeExactly $name
      $obj.Kind | Should -BeExactly $kind
      $obj.Items.Count | Should -Be 0
    }
    It 'Should validate properties of AnsiblePlay object' {
      $name = 'PlayName'
      $kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages
      $items = @([ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages]::new('Package', '1.0.0', $false))

      $obj = [ATAP.IAC.Ansible.AnsiblePlay]::new($name, $kind, $items)

      $obj.Name | Should -BeExactly $name
      $obj.Kind | Should -BeExactly $kind
      $obj.Items[0].Name | Should -BeExactly 'Package'
    }
    It 'Should convert AnsiblePlay object to YAML and back' {
      $name = 'PlayName'
      $kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages
      $items = @([ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages]::new('Package', '1.0.0', $false))

      $obj = [ATAP.IAC.Ansible.AnsiblePlay]::new($name, $kind, $items)
      $yaml = $obj | ConvertTo-Yaml
      $reconstructedObj = $yaml | ConvertFrom-Yaml

      $reconstructedObj.Name | Should -BeExactly $name
      $reconstructedObj.Kind | Should -BeExactly $kind.ToString() # Type might be a string in reconstructed YAML object
      $reconstructedObj.Items[0].Name | Should -BeExactly 'Package'
    }
    It 'Should create AnsiblePlay object with two items' {
      $name = 'PlayName'
      $kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages
      $item1 = [ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages]::new('Package1', '1.0.0', $false)
      $item2 = [ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages]::new('Package2', '2.0.0', $false)
      $items = @($item1, $item2)

      $obj = [ATAP.IAC.Ansible.AnsiblePlay]::new($name, $kind, $items)

      $obj.Name | Should -BeExactly $name
      $obj.Kind | Should -BeExactly $kind
      $obj.Items.Count | Should -Be 2
      $obj.Items[0].Name | Should -BeExactly 'Package1'
      $obj.Items[1].Name | Should -BeExactly 'Package2'
    }
    It 'Should convert AnsiblePlay object with three items to and from YAML correctly' {
      $name = 'PlayName'
      $kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages
      $item1 = [ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages]::new('Package1', '1.0.0', $false)
      $item2 = [ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages]::new('Package2', '2.0.0', $false)
      $item3 = [ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages]::new('Package3', '3.0.0', $false)
      $items = [System.Collections.Generic.List[ATAP.IAC.Ansible.IAnsiblePlayBlockCommon]]::new()
      $items.Add($item1)
      $items.Add($item2)
      $items.Add($item3)

      $obj = [ATAP.IAC.Ansible.AnsiblePlay]::new($name, $kind, $items)

      $yaml = $obj | ConvertTo-Yaml
      $objFromYaml = $yaml | ConvertFrom-Yaml

      $objFromYaml.Name | Should -BeExactly $name
      $objFromYaml.Kind | Should -BeExactly $kind
      $objFromYaml.Items.Count | Should -Be 3
      $objFromYaml.Items[0].Name | Should -BeExactly 'Package1'
      $objFromYaml.Items[1].Name | Should -BeExactly 'Package2'
      $objFromYaml.Items[2].Name | Should -BeExactly 'Package3'
    }
  }
  Describe 'Testing AnsiblePlay class with AnsiblePlayBlockRegistrySettings' {
    It 'Should construct an AnsiblePlay object with AnsiblePlayBlockRegistrySettings' {
      $name = 'PlayName'
      $kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings
      $item1 = [ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings]::new('Purpose1', 'Setting1', 'Path1', 'Type1', 'Value1')
      $item2 = [ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings]::new('Purpose2', 'Setting2', 'Path2', 'Type2', 'Value2')
      $items = [System.Collections.Generic.List[ATAP.IAC.Ansible.IAnsiblePlayBlockCommon]]::new()
      $items.Add($item1)
      $items.Add($item2)

      $obj = [ATAP.IAC.Ansible.AnsiblePlay]::new($name, $kind, $items)

      $obj.Name | Should -BeExactly $name
      $obj.Kind | Should -BeExactly $kind
      $obj.Items.Count | Should -Be 2
    }

    It 'Should convert AnsiblePlay object with AnsiblePlayBlockRegistrySettings to and from YAML correctly' {
      $name = 'PlayName'
      $kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings
      $item1 = [ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings]::new('Purpose1', 'Setting1', 'Path1', 'Type1', 'Value1')
      $item2 = [ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings]::new('Purpose2', 'Setting2', 'Path2', 'Type2', 'Value2')
      $items = [System.Collections.Generic.List[ATAP.IAC.Ansible.IAnsiblePlayBlockCommon]]::new()
      $items.Add($item1)
      $items.Add($item2)

      $obj = [ATAP.IAC.Ansible.AnsiblePlay]::new($name, $kind, $items)
      $yaml = $obj | ConvertTo-Yaml
      $objFromYaml = $yaml | ConvertFrom-Yaml

      $objFromYaml.Name | Should -BeExactly $name
      $objFromYaml.Kind | Should -BeExactly $kind
      $objFromYaml.Items.Count | Should -Be 2
      $objFromYaml.Items[0].Purpose | Should -BeExactly 'Purpose1'
      $objFromYaml.Items[1].Purpose | Should -BeExactly 'Purpose2'
      $objFromYaml.Items[0].Name | Should -BeExactly 'Setting1'
      $objFromYaml.Items[1].Name | Should -BeExactly 'Setting2'
    }
  }
  Describe 'Testing AnsibleTask class with One Play having one AnsiblePlayBlockRegistrySettings' {
    It 'Should construct an AnsibleTask object with a single AnsiblePlay containing a single AnsiblePlayBlockRegistrySettings' {
      $taskName = 'TaskName'

      # Constructing AnsiblePlayBlockRegistrySettings
      $registrySettings = [ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings]::new('Purpose', 'Name', 'Path', 'Type', 'Value')
      # Constructing AnsiblePlay with a single AnsiblePlayBlockRegistrySettings
      $playName = 'PlayName'
      $playKind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings
      $playItems = [System.Collections.Generic.List[ATAP.IAC.Ansible.IAnsiblePlayBlockCommon]]::new()
      $playItems.Add($registrySettings)
      $ansiblePlay = [ATAP.IAC.Ansible.AnsiblePlay]::new($playName, $playKind, $playItems)
      # Constructing AnsibleTask with a single AnsiblePlay
      $ansiblePlays = [System.Collections.Generic.List[ATAP.IAC.Ansible.IAnsiblePlay]]::new()
      $ansiblePlays.Add($ansiblePlay)
      $ansibleTask = [ATAP.IAC.Ansible.AnsibleTask]::new($taskName, $ansiblePlays)
      # Validate
      $ansibleTask.Name | Should -BeExactly $taskName
      $ansibleTask.Items.Count | Should -Be 1
      $ansibleTask.Items[0].Name | Should -BeExactly $playName
      $ansibleTask.Items[0].Items.Count | Should -Be 1
      $ansibleTask.Items[0].Items[0].Purpose | Should -BeExactly 'Purpose'
      $ansibleTask.Items[0].Items[0].Name | Should -BeExactly 'Name'
      # Convert AnsibleTask to YAML
      $yamlString = $ansibleTask | ConvertTo-Yaml
      # Convert YAML back to AnsibleTask object
      $ansibleTaskFromYaml = $yamlString | ConvertFrom-Yaml
      # Validate that the constructed object matches the one reconstructed from YAML
      $ansibleTaskFromYaml.Name | Should -BeExactly $taskName
      $ansibleTaskFromYaml.Items.Count | Should -Be 1
      $ansibleTaskFromYaml.Items[0].Name | Should -BeExactly $playName
      $ansibleTaskFromYaml.Items[0].Items.Count | Should -Be 1
      $ansibleTaskFromYaml.Items[0].Items[0].Purpose | Should -BeExactly 'Purpose'
      $ansibleTaskFromYaml.Items[0].Items[0].Name | Should -BeExactly 'Name'
    }
  }

  Describe 'Testing AnsiblePlayBlockSymbolicLinks class with YAML conversions' {
    It 'Should create AnsiblePlayBlockSymbolicLinks object via constructor' {
      $name = 'testName'
      $source = 'testSource'
      $target = 'testTarget'
      $obj = [ATAP.IAC.Ansible.AnsiblePlayBlockSymbolicLinks]::new($name, $source, $target)
      $obj.Name | Should -BeExactly $name
      $obj.Source | Should -BeExactly $source
      $obj.Target | Should -BeExactly $target
    }
    It 'Should validate properties of AnsiblePlayBlockSymbolicLinks' {
      $obj = [ATAP.IAC.Ansible.AnsiblePlayBlockSymbolicLinks]::new('testName', 'testVersion', 'testTarget')
      $obj.Name = 'newName'
      $obj.Name | Should -BeExactly 'newName'
      $obj.Source = 'newVersion'
      $obj.Source | Should -BeExactly 'newVersion'
      $obj.Target = 'newTarget'
      $obj.Target | Should -BeExactly 'newTarget'
    }

    It 'Should convert AnsiblePlayBlockSymbolicLinks to YAML and back' {
      $obj = [ATAP.IAC.Ansible.AnsiblePlayBlockSymbolicLinks]::new('testName', 'testVersion', 'testTarget')
      # Convert to YAML
      $yamlString = ConvertTo-Yaml $obj
      $yamlString | Should -Not -BeNullOrEmpty
      # Convert back to object
      $newObj = ConvertFrom-Yaml $yamlString
      $newObj | Should -Not -BeNullOrEmpty
      $newObj.Name | Should -BeExactly 'testName'
      $newObj.Source | Should -BeExactly 'testVersion'
      $newObj.Target | Should -BeExactly 'testTarget'
    }
  }

  Describe 'AnsibleTask Tests with two AnsiblePlay objects' {
    It 'Should construct an AnsibleTask with two AnsiblePlay objects correctly' {
      $chocolateyPackage = New-Object ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages 'Package1', '1.0.0', $false
      $registrySetting1 = New-Object ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings 'Purpose1', 'Setting1', 'Path1', 'Type1', 'Value1'
      $registrySetting2 = New-Object ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings 'Purpose2', 'Setting2', 'Path2', 'Type2', 'Value2'
      $play1Name = 'Play1'
      $play1Kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages
      $play2Name = 'Play2'
      $play2Kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings
      $play1 = New-Object ATAP.IAC.Ansible.AnsiblePlay $play1Name, $play1Kind, @($chocolateyPackage)
      $play2 = New-Object ATAP.IAC.Ansible.AnsiblePlay $play2Name, $play2Kind, @($registrySetting1, $registrySetting2)
      $task = New-Object ATAP.IAC.Ansible.AnsibleTask 'Task1', @($play1, $play2)
      # Convert to YAML
      $yamlString = $task | ConvertTo-Yaml
      # Convert back from YAML
      $taskFromYaml = $yamlString | ConvertFrom-Yaml
      # Validate properties
      $taskFromYaml.Name | Should -BeExactly 'Task1'
      $taskFromYaml.Items[0].Name | Should -BeExactly 'Play1'
      $taskFromYaml.Items[1].Name | Should -BeExactly 'Play2'
      $taskFromYaml.Items[0].Items[0].Name | Should -BeExactly 'Package1'
      $taskFromYaml.Items[1].Items[0].Purpose | Should -BeExactly 'Purpose1'
      $taskFromYaml.Items[1].Items[0].Name | Should -BeExactly 'Setting1'
      $taskFromYaml.Items[1].Items[1].Purpose | Should -BeExactly 'Purpose2'
      $taskFromYaml.Items[1].Items[1].Name | Should -BeExactly 'Setting2'
    }
  }
  Describe 'AnsibleRole Tests' {
    It 'Should construct an AnsibleRole and serialize / deserialize it to / from YAML' {
      $chocolateyPackage = New-Object ATAP.IAC.Ansible.AnsiblePlayBlockChocolateyPackages 'Package1', '1.0.0', $false
      $registrySetting1 = New-Object ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings 'Purpose1', 'Setting1', 'Path1', 'Type1', 'Value1'
      $registrySetting2 = New-Object ATAP.IAC.Ansible.AnsiblePlayBlockRegistrySettings 'Purpose2', 'Setting2', 'Path2', 'Type2', 'Value2'
      $play1Name = 'Play1'
      $play1Kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages
      $play2Name = 'Play2'
      $play2Kind = [ATAP.IAC.Ansible.AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings
      $play1 = New-Object ATAP.IAC.Ansible.AnsiblePlay $play1Name, $play1Kind, @($chocolateyPackage)
      $play2 = New-Object ATAP.IAC.Ansible.AnsiblePlay $play2Name, $play2Kind, @($registrySetting1, $registrySetting2)
      $task = New-Object ATAP.IAC.Ansible.AnsibleTask 'Task1', @($play1, $play2)
      $meta = New-Object ATAP.IAC.Ansible.AnsibleMeta
      $meta.DependentRoleNames = 'DependentRole1, DependentRole2'
      $role = New-Object ATAP.IAC.Ansible.AnsibleRole 'Role1', $meta, $task
      # Convert to YAML
      $yamlString = $role | ConvertTo-Yaml

      # Convert back from YAML
      $roleFromYaml = $yamlString | ConvertFrom-Yaml

      # Validate properties
      $roleFromYaml.Name | Should -BeExactly 'Role1'
      $roleFromYaml.AnsibleTask.Name | Should -BeExactly 'Task1'
      $roleFromYaml.AnsibleMeta.DependentRoleNames | Should -BeExactly 'DependentRole1, DependentRole2'
      $roleFromYaml.AnsibleTask.Items[0].Name | Should -BeExactly 'Play1'
      $roleFromYaml.AnsibleTask.Items[1].Name | Should -BeExactly 'Play2'
      $roleFromYaml.AnsibleTask.Items[0].Items[0].Name | Should -BeExactly 'Package1'
      $roleFromYaml.AnsibleTask.Items[1].Items[0].Purpose | Should -BeExactly 'Purpose1'
      $roleFromYaml.AnsibleTask.Items[1].Items[0].Name | Should -BeExactly 'Setting1'
      $roleFromYaml.AnsibleTask.Items[1].Items[1].Purpose | Should -BeExactly 'Purpose2'
      $roleFromYaml.AnsibleTask.Items[1].Items[1].Name | Should -BeExactly 'Setting2'
    }
  }
}






