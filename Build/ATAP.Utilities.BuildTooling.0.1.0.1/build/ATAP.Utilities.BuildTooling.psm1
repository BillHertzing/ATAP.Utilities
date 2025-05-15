<#
	My Function
#>
Function Remove-ObjAndBinSubdirs {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$itempath
    , [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$solutionpath
  )
  Write-Verbose "$solutionpath $projectpath $itempath "
  $rootpath = $itempath
  Write-Verbose "$rootpath"
  Write-Verbose "Removing obj and bin subdirs recursively below $rootpath"
  $dirsToDelete = 'obj', 'bin'
  Get-ChildItem -Recurse -Directory $rootpath | ForEach-Object { $dir = $_
    if ($dirsToDelete -Contains $dir.Name) {
      if ($PSCmdlet.ShouldProcess($dir.Name, 'Delete')) {
        $n = $dir.Fullname
        Write-Host "really would delete $n"
      }
    }
  }
}

#
Function Remove_VSComponentCache {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param()
  Write-Verbose 'starting Remove_VSComponentCache'
  Write-Verbose "Removing ($ENV:AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache"
  if ($PSCmdlet.ShouldProcess("($ENV:AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache", 'Delete')) {
				Write-Host "really would delete ($ENV:AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache"
		}
}

Function create-DocFolderIfNotPresent {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectPath
  )
  Write-Verbose "ProjectPath is $ProjectPath, adding a DOC folder if not present"
  if ($PSCmdlet.ShouldProcess("$ProjectPath\Docs", 'Create')) {
				New-Item -Path "$ProjectPath\Docs" -ItemType Directory -Force
		}
}

Function create-DocFilesIfNotPresent {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DocsPath
    , [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$DocFileNames
  )
  Write-Verbose "DocsPath is $DocsPath, error if not present"
  if (!Test-Path -Path $DocsPath) { throw "$DocsPath is not present" }
  $DocFileNames | ForEach-Object { $dfn = $_
    $dfp = Join-Path $DocsPath $dfn
    if (Test-Path -Path $dfp) {
      Write-Verbose "DocFullPath $dfp already exists"
    } else {
      if ($PSCmdlet.ShouldProcess("$dfp", 'Create')) {
        Write-Verbose "Creating empty file $dfp, utf-8 encoding, no BOM"
        [io.file]::WriteAllText($dfp, '', (New-Object System.Text.UTF8Encoding($false)))
      }
    }
  }
}


