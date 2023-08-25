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
if ($false) {
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
$C1list1 =[System.Collections.Generic.List[IAnsiblePlayBlockAny]]::new()
$C1list1.Add($AnsiblePlayBlockChocolateyPackagesInstance1)
$C1list2 =[System.Collections.Generic.List[IAnsiblePlayBlockAny]]::new()
$C1list2.Add($AnsiblePlayBlockChocolateyPackagesInstance1)
$C1list2.Add($AnsiblePlayBlockChocolateyPackagesInstance2)
$Mixedlist =[System.Collections.Generic.List[IAnsiblePlayBlockAny]]::new()
$C1list2 =[System.Collections.Generic.List[IAnsiblePlayBlockAny]]::new()
$C1list2.Add($AnsiblePlayBlockChocolateyPackagesInstance1)

# Create a List and add the AnsiblePlayBlockRegistrySettings instance to it
$C2list1 =[System.Collections.Generic.List[IAnsiblePlayBlockAny]]::new()
$C2list1.Add($AnsiblePlayBlockRegistrySettingsInstance1)
$C2list2 =[System.Collections.Generic.List[IAnsiblePlayBlockAny]]::new()
$C2list2.Add($AnsiblePlayBlockRegistrySettingsInstance1)
$C2list2.Add($AnsiblePlayBlockRegistrySettingsInstance2)

$C1list1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$C1list2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$C2list1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$C2list2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml

# Create instances of ListOfAnsiblePlayBlockAny with the lists
$c1l1 = [ListOfAnsiblePlayBlockAny]::new( [AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages, $C1list1)
$c1l2 = [ListOfAnsiblePlayBlockAny]::new( [AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages, $C1list2)
$c2l1 = [ListOfAnsiblePlayBlockAny]::new( [AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings, $C2list1)
$c2l2 = [ListOfAnsiblePlayBlockAny]::new( [AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings, $C2list2)

$c1l1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$c1l2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$c2l1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$c2l2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml

$playc1l1 = [AnsiblePlay]::new('playc1l1',$c1l1)
$playc1l2 = [AnsiblePlay]::new('playc1l2',$c1l2)
$playc2l1 = [AnsiblePlay]::new('playc2l1',$c2l1)
$playc2l2 = [AnsiblePlay]::new('playc2l2',$c2l2)

$playc1l1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$playc1l2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$playc2l1 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$playc2l2 | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml

$AnsiblePlays = @($playc1l1,$playc1l2,$playc2l1,$playc2l2)

$taskHomogenous =  [AnsibleTask]::new('TheWholeTask',$AnsiblePlays)

$taskHomogenous | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml

"MixedLists"
$Mixedlist =[System.Collections.Generic.List[IAnsiblePlayBlockAny]]::new()
$Mixedlist.Add($AnsiblePlayBlockRegistrySettingsInstance1)
$Mixedlist.Add($AnsiblePlayBlockRegistrySettingsInstance2)
$Mixedlist.Add($AnsiblePlayBlockChocolateyPackagesInstance1)
$Mixedlist.Add($AnsiblePlayBlockChocolateyPackagesInstance2)
$Mixedlist | ConvertTo-Yaml | ConvertFrom-Yaml | Convertto-yaml
$MixedListOfAnsiblePlayBlock = [ListOfAnsiblePlayBlockAny]::new( [AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings, $C2list2)


$taskHomogenous.Name
foreach ($ansiblePlay in $taskHomogenous.Items) {
  "AnsiblePlayName = $($ansiblePlay.Name)"
  foreach ($ansiblePlayBlock in $ansiblePlay.Items) {

  }
}
