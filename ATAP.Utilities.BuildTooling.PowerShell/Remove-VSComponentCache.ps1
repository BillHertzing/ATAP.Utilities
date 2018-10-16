#
# Remove_VSComponentCache.ps1
#
[CmdletBinding(SupportsShouldProcess=$true)]



Function Remove_VSComponentCache {
    [CmdletBinding(SupportsShouldProcess=$true)]

	write-verbose "starting Remove_VSComponentCache"
	write-verbose "Removing ($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache"
			if ($PSCmdlet.ShouldProcess("($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache",'Delete')) {
				write-host "really would delete ($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache"
		}
}

Remove_VSComponentCache 
