<#
	My Function
#>
Function Remove-ObjAndBinSubdirs {
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

#
Function Remove_VSComponentCache {
    [CmdletBinding(SupportsShouldProcess=$true)]

	write-verbose "starting Remove_VSComponentCache"
	write-verbose "Removing ($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache"
			if ($PSCmdlet.ShouldProcess("($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache",'Delete')) {
				write-host "really would delete ($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache"
		}
}

Function create-DocFolderIfNotPresent {
    [CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[parameter(mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$ProjectPath
	)
	write-verbose "ProjectPath is $ProjectPath, adding a DOC folder if not present"
	if ($PSCmdlet.ShouldProcess("$ProjectPath\Docs",'Create')) {
				New-Item -Path "$ProjectPath\Docs" -ItemType Directory -Force
		}
}

Function create-DocFilesIfNotPresent {
    [CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[parameter(mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$DocsPath
    ,[parameter(mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string[]]$DocFileNames 
	)
	write-verbose "DocsPath is $DocsPath, error if not present"
  if (!Test-Path -Path $DocsPath) {throw "$DocsPath is not present"}
  $DocFileNames | % {$dfn = $_;
    $dfp = Join-path $DocsPath $dfn
    if (Test-Path -Path $dfp) {
      write-verbose "DocFullPath $dfp already exists"
    } else {
      if ($PSCmdlet.ShouldProcess("$dfp",'Create')) {
          write-verbose "Creating empty file $dfp, utf-8 encoding, no BOM"
				[io.file]::WriteAllText($dfp, "", (new-object  System.Text.UTF8Encoding($false)))
		  }
    }
  }
}


