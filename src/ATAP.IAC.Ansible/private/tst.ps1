using namespace  ATAP.IAC.Ansible
# using namespace  System.Collections.Generic

# ToDo: Make this opinionated based on something in the parent tree
$assemblyFileName = "ATAP.IAC.Ansible.dll"
$outputFilePath = join-path ".." $assemblyFileName
Add-Type -Path $outputFilePath

[System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

$AnsiblePlayBlockChocolateyPackagesInstance1 = [AnsiblePlayBlockChocolateyPackages]::new( 'AAnsiblePlayBlockChocolateyPackages', '1.2.3', $false)
$AnsiblePlayBlockChocolateyPackagesInstance2 = [AnsiblePlayBlockChocolateyPackages]::new( 'BAnsiblePlayBlockChocolateyPackages', '2.3.4', $false)
$AnsiblePlayBlockRegistrySettingsInstance1 = [AnsiblePlayBlockRegistrySettings]::new( 'CAnsiblePlayBlockRegistrySettings', 'HKLM-P1', 'SZ', 'str1')
$AnsiblePlayBlockRegistrySettingsInstance2 = [AnsiblePlayBlockRegistrySettings]::new( 'DAnsiblePlayBlockRegistrySettings', 'HKLM-P2', 'SZ', 'str2')

$AnsiblePlayBlockChocolateyPackagesInstance1|ConvertTo-Yaml
$AnsiblePlayBlockChocolateyPackagesInstance2|ConvertTo-Yaml
$AnsiblePlayBlockRegistrySettingsInstance1|ConvertTo-Yaml
$AnsiblePlayBlockRegistrySettingsInstance2|ConvertTo-Yaml

$AnsiblePlayBlockChocolateyPackagesInstance1|ConvertTo-Yaml|ConvertFrom-Yaml | ConvertTo-Yaml
$AnsiblePlayBlockChocolateyPackagesInstance2|ConvertTo-Yaml|ConvertFrom-Yaml | ConvertTo-Yaml
$AnsiblePlayBlockRegistrySettingsInstance1|ConvertTo-Yaml|ConvertFrom-Yaml | ConvertTo-Yaml
$AnsiblePlayBlockRegistrySettingsInstance2|ConvertTo-Yaml|ConvertFrom-Yaml | ConvertTo-Yaml

# Create a List and add the AnsiblePlayBlockChocolateyPackages instance to it
$C1list1 = @(,$AnsiblePlayBlockChocolateyPackagesInstance1)
$C1list2 = @($AnsiblePlayBlockChocolateyPackagesInstance1, $AnsiblePlayBlockChocolateyPackagesInstance2)
# Create a List and add the AnsiblePlayBlockRegistrySettings instance to it
$C2list1 = @(,$AnsiblePlayBlockRegistrySettingsInstance1)
$C2list2 = @($AnsiblePlayBlockRegistrySettingsInstance1, $AnsiblePlayBlockRegistrySettingsInstance2)

$C1list1 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml
$C1list2 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml
$C2list1 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml
$C2list2 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml

$playc1l1 = [AnsiblePlay]::new('playc1l1',[AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages,$C1list1)
$playc1l2 = [AnsiblePlay]::new('playc1l2',[AnsiblePlayBlockKind]::AnsiblePlayBlockChocolateyPackages,$C1list2)
$playc2l1 = [AnsiblePlay]::new('playc2l1',[AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings,$C2list1)
$playc2l2 = [AnsiblePlay]::new('playc2l2',[AnsiblePlayBlockKind]::AnsiblePlayBlockRegistrySettings,$C2list2)

$playc1l1 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml
$playc1l2 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml
$playc2l1 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml
$playc2l2 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml

$taskChocoOnly =  [AnsibleTask]::new('ChocoTasks',@($playc1l1,$playc1l2))
$taskChocoOnly | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml

$taskRegistryOnly =  [AnsibleTask]::new('RegistryTasks',@($playc2l1,$playc2l2))
$taskRegistryOnly | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml

"MixedTask"
$MixedPlays = @($playc1l1,$playc1l2,$playc2l1,$playc2l2)
$MixedTask =  [AnsibleTask]::new('MixedTask',$MixedPlays)

$MixedTask | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml

"CompactTask"
$compactYamlString = @"
Name: CompactTask
Items:
- Name: playc1l1
  Kind: AnsiblePlayBlockChocolateyPackages
  Items:
  - {Version: 1.2.3,    Name: AAnsiblePlayBlockChocolateyPackages,    Prerelease: false}
- Name: playc1l2
  Kind: AnsiblePlayBlockChocolateyPackages
  Items:
  - {Version: 1.2.3,    Name: AAnsiblePlayBlockChocolateyPackages,    Prerelease: false}
  - {Version: 2.3.4,    Name: BAnsiblePlayBlockChocolateyPackages,    Prerelease: false}
- Name: playc2l1
  Kind: AnsiblePlayBlockRegistrySettings
  Items:
  - Value: str1
    Path: HKLM-P1
    Name: CAnsiblePlayBlockRegistrySettings
    Type: SZ
- Name: playc2l2
  Kind: AnsiblePlayBlockRegistrySettings
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

$compactTask = $compactYamlString| ConvertFrom-Yaml
$compactTask | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml

"WalkTask"
$compactTask.Name
foreach ($ansiblePlay in $compactTask.Items) {
  "AnsiblePlayName = $($ansiblePlay.Name)"
  "AnsiblePlayKind = $($ansiblePlay.Kind)"
  foreach ($ansiblePlayBlockCommon in $ansiblePlay.Items) {
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

# $c1l1 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml
# $c1l2 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml
# $c2l1 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml
# $c2l2 | ConvertTo-Yaml | ConvertFrom-Yaml | ConvertTo-Yaml

