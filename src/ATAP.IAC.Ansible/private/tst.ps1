using namespace  ATAP.Utilities.Ansible
using namespace  System.Collections.Generic

# add references to external assemblies. Ensure the assemblies referenced are compatable with the current default DotNet framework
# reference the YamlDotNet.dll assembly found in the current directory
$yamlDotNetAssemblyPath = Join-Path '..' 'YamlDotNet.dll'

$referencedAssemblies = @(
  $yamlDotNetAssemblyPath
  'System.Collections.dll'
)

[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

[void]$sb.Append($(Get-Content 'test.cs' -Raw))
$outputFilePath = Join-Path '..' 'testTypes.dll'
if ($true) {
  if (Test-Path $outputFilePath) { Remove-Item $outputFilePath -Force }
  Add-Type -TypeDefinition $sb.ToString() -ReferencedAssemblies $referencedAssemblies -OutputAssembly $outputFilePath
}
Add-Type -Path $outputFilePath
$AnsiblePlayBlockChocolateyPackagesInstance1 = [AnsiblePlayBlockChocolateyPackages]::new( 'AAnsiblePlayBlockChocolateyPackages', '1.2.3', $false)
$AnsiblePlayBlockChocolateyPackagesInstance2 = [AnsiblePlayBlockChocolateyPackages]::new( 'BAnsiblePlayBlockChocolateyPackages', '2.3.4', $false)
$AnsiblePlayBlockRegistrySettingsInstance1 = [AnsiblePlayBlockRegistrySettings]::new( 'CAnsiblePlayBlockRegistrySettings', 'HKLM-P1', 'SZ', 'str1')
$AnsiblePlayBlockRegistrySettingsInstance2 = [AnsiblePlayBlockRegistrySettings]::new( 'DAnsiblePlayBlockRegistrySettings', 'HKLM-P2', 'SZ', 'str2')

$AnsiblePlayBlockChocolateyPackagesInstance1|ConvertTo-Yaml
$AnsiblePlayBlockChocolateyPackagesInstance2|ConvertTo-Yaml
$AnsiblePlayBlockRegistrySettingsInstance1|ConvertTo-Yaml
$AnsiblePlayBlockRegistrySettingsInstance2|ConvertTo-Yaml

$AnsiblePlayBlockChocolateyPackagesInstance1|ConvertTo-Yaml|ConvertFrom-Yaml | Convertto-yaml
$AnsiblePlayBlockChocolateyPackagesInstance2|ConvertTo-Yaml|ConvertFrom-Yaml | Convertto-yaml
$AnsiblePlayBlockRegistrySettingsInstance1|ConvertTo-Yaml|ConvertFrom-Yaml | Convertto-yaml
$AnsiblePlayBlockRegistrySettingsInstance2|ConvertTo-Yaml|ConvertFrom-Yaml | Convertto-yaml

# Create a List and add the AnsiblePlayBlockChocolateyPackages instance to it
$C1list1 = @(,$AnsiblePlayBlockChocolateyPackagesInstance1)
$C1list2 = @($AnsiblePlayBlockChocolateyPackagesInstance1, $AnsiblePlayBlockChocolateyPackagesInstance2)
# Create a List and add the AnsiblePlayBlockRegistrySettings instance to it
$C2list1 = @(,$AnsiblePlayBlockRegistrySettingsInstance1)
$C2list2 = @($AnsiblePlayBlockRegistrySettingsInstance1, $AnsiblePlayBlockRegistrySettingsInstance2)

$C1list1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$C1list2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$C2list1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$C2list2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml

$playc1l1 = [AnsiblePlay]::new('playc1l1',$C1list1)
$playc1l2 = [AnsiblePlay]::new('playc1l2',$C1list2)
$playc2l1 = [AnsiblePlay]::new('playc2l1',$C2list1)
$playc2l2 = [AnsiblePlay]::new('playc2l2',$C2list2)

$playc1l1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$playc1l2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$playc2l1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$playc2l2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml


$taskChocoOnly =  [AnsibleTask]::new('ChocoTasks',@($playc1l1,$playc1l2))
$taskChocoOnly | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml

$taskRegistryOnly =  [AnsibleTask]::new('RegistryTasks',@($playc2l1,$playc2l2))
$taskRegistryOnly | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml

"MixedLists"
$MixedPlays = @($playc1l1,$playc1l2,$playc2l1,$playc2l2)
$MixedTasks =  [AnsibleTask]::new('MixedTask',$MixedPlays)

$MixedTasks | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml

$mixedYamlString = @"
Name: MixedTask
Items:
- Name: playc1l1
  Items:
  - Version: 1.2.3
    Name: AAnsiblePlayBlockChocolateyPackages
    Prerelease: false
- Name: playc1l2
  Items:
  - Version: 1.2.3
    Name: AAnsiblePlayBlockChocolateyPackages
    Prerelease: false
  - Version: 2.3.4
    Name: BAnsiblePlayBlockChocolateyPackages
    Prerelease: false
- Name: playc2l1
  Items:
  - Value: str1
    Path: HKLM-P1
    Name: CAnsiblePlayBlockRegistrySettings
    Type: SZ
- Name: playc2l2
  Items:
  - Value: str1
    Path: HKLM-P1
    Name: CAnsiblePlayBlockRegistrySettings
    Type: SZ
  - Value: str2
    Path: HKLM-P2
    Name: DAnsiblePlayBlockRegistrySettings
    Type: SZ
"@

$mixedYamlTask = $mixedYamlString| ConvertFrom-Yaml

$mixedYamlTask.Name
foreach ($ansiblePlay in $MimixedYamlTaskxedTasks.Items) {
  "AnsiblePlayName = $($ansiblePlay.Name)"
  foreach ($ansiblePlayBlockCommon in $ansiblePlay.Items) {
    "AnsiblePlayKind = $($ansiblePlayBlockCommon.Kind)"
  }
}


# Create a List and add the AnsiblePlayBlockChocolateyPackages instance to it
# $C1list1 =[System.Collections.Generic.List[IAnsiblePlayBlockCommon]]::new()
# $C1list1.Add($AnsiblePlayBlockChocolateyPackagesInstance1)
# $C1list2 =[System.Collections.Generic.List[IAnsiblePlayBlockCommon]]::new()
# $C1list2.Add($AnsiblePlayBlockChocolateyPackagesInstance1)
# $C1list2.Add($AnsiblePlayBlockChocolateyPackagesInstance2)
# Create a List and add the AnsiblePlayBlockRegistrySettings instance to it
# $C2list1 =[System.Collections.Generic.List[IAnsiblePlayBlockCommon]]::new()
# $C2list1.Add($AnsiblePlayBlockRegistrySettingsInstance1)
# $C2list2 =[System.Collections.Generic.List[IAnsiblePlayBlockCommon]]::new()
# $C2list2.Add($AnsiblePlayBlockRegistrySettingsInstance1)
# $C2list2.Add($AnsiblePlayBlockRegistrySettingsInstance2)

# Create instances of ListOfAnsiblePlayBlockAny with the lists
# $c1l1 = [ListOfAnsiblePlayBlockAny]::new( [AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages, $C1list1)
# $c1l2 = [ListOfAnsiblePlayBlockAny]::new( [AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages, $C1list2)
# $c2l1 = [ListOfAnsiblePlayBlockAny]::new( [AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings, $C2list1)
# $c2l2 = [ListOfAnsiblePlayBlockAny]::new( [AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings, $C2list2)

# $c1l1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
# $c1l2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
# $c2l1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
# $c2l2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml

