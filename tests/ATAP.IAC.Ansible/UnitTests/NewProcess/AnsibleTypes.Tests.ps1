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
  # Custom assemblies created to be tested is found in <RepoRootPath>/<ModuleName>/<assemblyname.dll>

  #  find the scrript or the .dll to be ested, based on the name of this test file


  $moduleNameSeperator = '.'
  $sUTNameSeperator = '.'
  $sUTRelativePrefix = Join-Path '..' '..' 'src'
  $sUTRelativeToModulePaths = @('.\','.\public', '.\private')
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



  # Import the custom Types being tested
  # add references to external assemblies. Ensure the assemblies referenced are compatable with the current default DotNet framework
  # reference the YamlDotNet.dll assembly found in the parent directory. Paent should be the module's main packge direcotry, a peer of the .psm1 and .psd1 files.
  # This allows access to the YamlDotNet library functions without the need to install it via the Powershell Gallery.
  # NOTE: the YamlDotNet.dll assembly must be compatable with the current default.Net framework version installed on the system

  if ($env:Environment -eq 'Development') {
    # when the script is run from a development environment, use the below line to reference the DLL in the parent directory
    $ModuleCustomTypesAssemblyPath = Join-Path (Get-Item $PSScriptRoot).parent.FullName 'ATAP.Utilities.Ansible.dll'
  }
  else {
    # when the script is run from a production or QualityAssurance environment, use the below line to reference the DLL in the module's main package directory
    $ModuleCustomTypesAssemblyPath = Join-Path $PSScriptRoot 'ATAP.Utilities.Ansible.dll'
  }
  # Load the custom DLL
  Add-Type -Path $ModuleCustomTypesAssemblyPath

  # appears to  be not neede
  # # Load Dependent DLLs  in order to execute the tests
  # if ($env:Environment -eq 'Development') {
  #   # when the script is run from a development environment, use the below line to reference the DLL in the parent directory
  #   $dependentAssemblyPath = join-path (get-item $PSScriptRoot).parent.FullName "YamlDotNet.dll"
  #   } else {
  #   # when the script is run from a production or QualityAssurance environment, use the below line to reference the DLL in the module's main package directory
  #   $dependentAssemblyPath = join-path $PSScriptRoot "YamlDotNet.dll"
  #   }
  #   # Load the Dependent DLL
  #   #Add-Type -Path $dependentAssemblyPath


  $referencedAssemblies = @(
    $yamlDotNetAssemblyPath
    'System.Collections.dll'
  )
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






