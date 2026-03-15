
function Get-ChocolateyPackagesFromAnsibleInventoryObject {
	param(
	[string] $PathToAnsibleInventoryObject = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Get-AnsibleInventory.ps1'
	,[string] $DestinationPath = 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\_generated\ChocoPackagesFromInventoryGroups.txt'
	)

  $ansibleInventory = . $PathToAnsibleInventoryObject

  $ansibleInventory['AnsibleGroupNames'].keys |
    ForEach-Object{$h = $_; $ansibleInventory['AnsibleGroupNames'][$h]['ChocolateyPackageNames']} |
    Sort-Object -Unique |
    set-content -path $DestinationPath
  Get-Content $DestinationPath
}

