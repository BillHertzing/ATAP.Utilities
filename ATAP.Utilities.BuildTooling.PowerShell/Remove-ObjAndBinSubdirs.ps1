[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$itempath
	,[parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$solutionpath
	,[parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$projectpath
)


Function remove-objandBin {
    [CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[parameter(mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$itempath
		,[parameter(mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$solutionpath
	)
	write-verbose "$solutionpath $projectpath $itempath "
	$rootpath = $itempath
	write-verbose "$rootpath"
	write-verbose "Removing obj and bin subdirs recursively below $rootpath"
	$dirsToDelete= 'obj','bin'
	Get-ChildItem -Recurse -Directory $rootpath | %{$dir = $_;
		if ($dirsToDelete -Contains $dir.Name) {
			if ($PSCmdlet.ShouldProcess($dir.Name,'Delete')) {
				$n= $dir.Fullname
				write-host "really would delete $n"
			}
		}
	}
}

remove-objandBin $itempath $solutionpath



