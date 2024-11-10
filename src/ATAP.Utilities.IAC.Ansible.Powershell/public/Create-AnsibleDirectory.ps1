
# add the namespace for the custom types defined and used in this module
using namespace ATAP.IAC.Ansible
[CmdletBinding(DefaultParameterSetName = 'FromFilesystem')]
param (
  # ToDo: parameterSet and error handling
  [string] $projectBaseDirectory = '.',
  # ParameterSet information for InventorySource as a Powershell script file on the filesystem
  [Parameter(ParameterSetName = 'FromFilesystem')]
  [string] $ansibleInventorySourcePath = './'
  # ParameterSet information for InventorySource as a Powershell script file from a vault
)
# ToDo: move to powershell utilities
function convertFromYamlWithErrorHandling {
  param (
    # ToDo: error handling
    [string]$path
  )
  # ToDo: error handling
  ConvertFrom-Yaml -Yaml $(Get-Content -Path $path -Raw )
}

$assemblyFileName = 'ATAP.IAC.Ansible.dll'
# ToDo: figure out how to load from either the production package, QAPackage, or development filesystem
$assemblyFilePath = Join-Path 'C:' 'Dropbox' 'whertzing' 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.IAC.Ansible' 'Resources' $assemblyFileName
$assemblyFileInfo = Get-ChildItem $assemblyFilePath
Add-Type -Path $assemblyFileInfo.FullName

# Create the ansibleStructure hashtable from $ansibleInventorySourcePath script file
$ansibleStructure = @{}
if ( $PsCmdlet.ParameterSetName -eq 'FromFilesystem') {
  # ToDo: use ATAP.IAC packaging
  $ansibleInventorySourcePath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Get-AnsibleInventory.ps1'
  # Get-AnsibleInventory.ps1 script file
  . $ansibleInventorySourcePath
  # execute the Get-AnsibleInventory function from the Get-AnsibleInventory.ps1 script file
  $ansibleStructure = Get-AnsibleInventory
} elseif ( $PsCmdlet.ParameterSetName -eq 'FromVault') {
  $message = 'Inventory from vault not supported'
  Write-PSFMessage -Level Error -Message $message -Tag 'Unsupported'
  throw $message
}


# Get the built-in defaults combined with the approved for
#  - the Chocolatey packages (name, version, allowPreRelease, installationarguments, RegistrySettings, GlobalSettings, ScheduledJobs)
#  - the NuGet Packages (name, version, allowPreRelease, installationarguments, RegistrySettings, GlobalSettings, ScheduledJobs)
#  - the PowershellGet packages (name, version, allowPreRelease, installationarguments, RegistrySettings, GlobalSettings, ScheduledJobs)
#  - the Powershell modules
#  - the RegistrySetting (Key:string, name:string,type,value)
#  - the GlobalSettings (Key:string, value: TBD)
#  - the PKICertificates
#  - the scheduled jobs

# ToDo - the location and content of these files comes from the SWBOM reporting and updating processes
$SWBOMResourcesPath = Join-Path 'C:' 'Dropbox' 'whertzing' 'GitHub' 'ATAP.IAC' 'Resources'
$approvedChocolateyPackagesInfoPath = Join-Path $SWBOMResourcesPath 'ApprovedChocolateyPackagesInfo.yml'
$approvedPowershellModulesInfoPath = Join-Path $SWBOMResourcesPath 'ApprovedPowershellModulesInfo.yml'
$approvedRegistrySettingsInfoPath = Join-Path $SWBOMResourcesPath 'ApprovedRegistrySettingsInfo.yml'
$approvedWindowsFeaturesInfoPath = Join-Path $SWBOMResourcesPath 'ApprovedWindowsFeaturesInfo.yml'
$approvedAnsibleRolesInfoPath = Join-Path $SWBOMResourcesPath 'ApprovedAnsibleRolesInfo.yml'
# ToDo: figure out how to load from either the production package, QAPackage, or development filesystem
# Resources path
$resourcesPath = Join-Path 'C:' 'Dropbox' 'whertzing' 'GitHub' 'ATAP.Utilities' 'src' 'ATAP.IAC.Ansible' 'Resources'
$defaultChocolateyPackagesInfoPath = Join-Path $resourcesPath 'DefaultChocolateyPackagesInfo.yml'
$defaultPowershellModulesInfoPath = Join-Path $resourcesPath 'DefaultPowershellModulesInfo.yml'
$defaultRegistrySettingsInfoPath = Join-Path $resourcesPath 'DefaultRegistrySettingsInfo.yml'
$defaultWindowsFeaturesInfoPath = Join-Path $resourcesPath 'DefaultWindowsFeaturesInfo.yml'
$defaultAnsibleRolesInfoPath = Join-Path $resourcesPath 'DefaultAnsibleRolesInfo.yml'

# This internal structure holds union of the default values with the values that come from organization's inventory (Get-AnsibleInventory)
#  the organization's inventory is transferred from <organizationName>.IAC package
#  combine the default Infos with the approved Infos, with approved taking higher precedence
$SwCfgInfos = @{
  NuGetPackageInfos      = $nugetPackagesInfos
  ChocolateyPackageInfos = Get-ClonedAndModifiedHashtable $(convertFromYamlWithErrorHandling $defaultChocolateyPackagesInfoPath) $(convertFromYamlWithErrorHandling $approvedChocolateyPackagesInfoPath)
  PowershellModuleInfos  = Get-ClonedAndModifiedHashtable $(convertFromYamlWithErrorHandling $defaultPowershellModulesInfoPath) $(convertFromYamlWithErrorHandling $approvedPowershellModulesInfoPath)
  RegistrySettingsInfos  = Get-ClonedAndModifiedHashtable $(convertFromYamlWithErrorHandling $defaultRegistrySettingsInfoPath) $(convertFromYamlWithErrorHandling $approvedRegistrySettingsInfoPath)
  WindowsFeatureInfos    = Get-ClonedAndModifiedHashtable $(convertFromYamlWithErrorHandling $defaultWindowsFeaturesInfoPath) $(convertFromYamlWithErrorHandling $approvedWindowsFeaturesInfoPath)
  AnsibleRoleInfos       = Get-ClonedAndModifiedHashtable $(convertFromYamlWithErrorHandling $defaultAnsibleRolesInfoPath) $(convertFromYamlWithErrorHandling $approvedAnsibleRolesInfoPath)
}

# ToDo: eventually the organization's IAC package will encapsulate this and import it all automatically
# These are names that define direcotry and files. these are generated by this script, and used by the Linux Ansible runtime
$securitySubdirectory = 'security'
$playbooksSubdirectory = 'playbooks'
$ansibleSubdirectoryNames = @($securitySubdirectory, 'group_vars', 'host_vars', $playbooksSubdirectory, 'roles', 'scripts')
$roleSubdirectoryNames = @('tasks', 'handlers', 'templates', 'files', 'vars', 'defaults', 'meta', 'library', 'tests', 'module_utils', 'lookup_plugins', 'scripts')
# the name of the main Ansible playbook. it 'includes' all the ansibleGroupNamePlaybooks
$mainPlaybookName = 'main.yml'
# the name of the top-level buildout playbook. It 'includes' a buildoutPlaybook for every host
$buildoutPlaybookName = 'buildoutPlaybook.yml'

# The ReadMe documentation filename
$ReadMeFileName = 'ReadMe.md'
# default name of the main YML file in each subdirectory
$mainYMLFileName = 'main.yml'

# These are the path names for the generated directories that this script produces
$generatedDirectoryPath = '../_generated'
# ToDo: the name and version of a specific generated subdirectory for an organization should be calculated from the organization's IAC package
$organizationName = 'ATAP'
$organizationsAnsibleSubdirectoryVersion = '0.0.1'
$generatedProjectDirectoryPath = Join-Path $projectBaseDirectory $generatedDirectoryPath $organizationName $organizationsAnsibleSubdirectoryVersion

$lifecycleNames = @('DevelopmentLFC', 'QualityAssuranceLFC', 'StagingLFC', 'ProductionLFC')


# template (preamble) for new, empty .yml files
$ymlTemplate = @'
---
# code: language=ansible
# {1} for {2}

'@

# Begin the creation of the Ansible directory here
# Create generated directory if it does not exists
New-Item -ItemType Directory -Path $generatedDirectoryPath -ErrorAction SilentlyContinue >$null
# Create generated Project directory
New-Item -ItemType Directory -Path $generatedProjectDirectoryPath -ErrorAction SilentlyContinue >$null
# Create base directory everything else is relative to this location
$baseDirectory = Join-Path $generatedProjectDirectoryPath 'Ansible'
New-Item -ItemType Directory -Path $baseDirectory -ErrorAction SilentlyContinue >$null

# create the direct subdirectories of the $baseDirectory
for ($ansibleSubdirectoryNameIndex = 0; $ansibleSubdirectoryNameIndex -lt $ansibleSubdirectoryNames.count; $ansibleSubdirectoryNameIndex++) {
  New-Item -ItemType Directory -Path $(Join-Path $baseDirectory $ansibleSubdirectoryNames[$ansibleSubdirectoryNameIndex]) -ErrorAction SilentlyContinue >$null
}

# the names of the inventory files
# ToDo: Create Ansible inventory files from the ansibleInventory object
$inventoryFileNames = [ordered] @{
  NonProductionInventory = @{source = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Wsl2Ubuntu\AnsibleNonProductionInventory.yml'; destination = 'nonproduction_inventory.yml' }
  ProductionInventory    = @{source = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Wsl2Ubuntu\AnsibleProductionInventory.yml'; destination = 'production_inventory.yml' }
}

# Copy the ansible inventory files to their destinations
for ($index = 0; $index -lt $($inventoryFileNames.Keys).count; $index++) {
  $inventoryDestinationPath = Join-Path $baseDirectory $($inventoryFileNames[$index]).destination
  Set-Content -Path $inventoryDestinationPath -Value $(Get-Content $($inventoryFileNames[$index]).source)
}

