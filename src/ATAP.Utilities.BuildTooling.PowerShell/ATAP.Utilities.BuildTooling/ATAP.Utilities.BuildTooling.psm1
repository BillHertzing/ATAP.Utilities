<#
	Remove-ObjAndBinSubdirs
#>
Function Remove-ObjAndBinSubdirs {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $path = "D:\Temp\GenerateProgramArtifacts"
  )
  $dirsToDelete = 'obj', 'bin'
  write-verbose "path = $path "
  # validate path exists
  if (!(test-path -Path $path)) { throw "$path was not found" }
  write-verbose "Removing obj and bin subdirs recursively below $path"
  # build alternation (OR) pattern for directory names as returned by gci, anchored to the end : (\\obj|\\bin)$
  $MatchRegex = "(" + (($dirstodelete | %{"\\"+$_}) -Join('|'))
  $MatchRegex= $MatchRegex + ")$"
  $pathsToDelete = Get-ChildItem -Recurse -Directory $path | where-object { $_.psISContainer -and ($_.fullname -match $MatchRegex) }
  write-verbose "Removing $($pathsToDelete.Length) directories:  $pathsTo$($pathsToDelete -join [environment]::NewLine)"
  $pathsToDelete | Foreach-object {
    $dirToDelete = $_
    if ($PSCmdlet.ShouldProcess("$dirToDelete", "Delete Directory")) {
      #remove-item -WhatIf:$WhatIfPreference -recurse $dirToDelete
      write-verbose "remove-item -WhatIf:$WhatIfPreference -recurse $dirToDelete"
    }
  }
}


# Function Remove_VSComponentCache {
#   [CmdletBinding(SupportsShouldProcess = $true)]

#   write-verbose "starting Remove_VSComponentCache"
#   write-verbose "Removing ($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache"
#   if ($PSCmdlet.ShouldProcess("($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache", 'Delete')) {
# 				write-host "really would delete ($ENV:\AppData)\Local\Microsoft\VisualStudio\15.0\ComponentModelCache"
# 		}
# }

# #
# Function Empty-NuGetCaches {
#   [CmdletBinding(SupportsShouldProcess = $true)]

#   # ToDo: rewrite using powershell NuGet or dotnet nuget commands?
#   write-verbose "starting Empty-NuGetCaches"
#   write-verbose "Removing ($ENV:\AppData)\Local\NuGet\v3-cache"
#   if ($PSCmdlet.ShouldProcess("($ENV:\AppData)\Local\NuGet\v3-cache", 'Delete')) {
# 				write-host "really would delete ($ENV:\AppData)\Local\NuGet\v3-cache"
# 		}
#   write-verbose "Removing ($ENV:\USERPROFILE)\.nuget\packages"
#   if ($PSCmdlet.ShouldProcess("($ENV:\USERPROFILE)\.nuget\packages", 'Delete')) {
# 				write-host "really would delete ($ENV:\USERPROFILE)\.nuget\packages"
# 		}
#   write-verbose "Removing ($ENV:\AppData)\Local\Temp\NuGetScratch"
#   if ($PSCmdlet.ShouldProcess("($ENV:\AppData)\Local\Temp\NuGetScratch", 'Delete')) {
# 				write-host "really would delete ($ENV:\AppData)\Local\Temp\NuGetScratch"
# 		}
# }

# Function create-DocFolderIfNotPresent {
#   [CmdletBinding(SupportsShouldProcess = $true)]
#   param (
#     [parameter(mandatory = $true)]
#     [ValidateNotNullOrEmpty()]
#     [string]$ProjectPath
#   )
#   write-verbose "ProjectPath is $ProjectPath, adding a DOC folder if not present"
#   if ($PSCmdlet.ShouldProcess("$ProjectPath\Docs", 'Create')) {
# 				New-Item -Path "$ProjectPath\Docs" -ItemType Directory -Force
# 		}
# }

# Function create-DocFilesIfNotPresent {
#   [CmdletBinding(SupportsShouldProcess = $true)]
#   param (
#     [parameter(mandatory = $true)]
#     [ValidateNotNullOrEmpty()]
#     [string]$DocsPath
#     , [parameter(mandatory = $true)]
#     [ValidateNotNullOrEmpty()]
#     [string[]]$DocFileNames
#   )
#   write-verbose "DocsPath is $DocsPath, error if not present"
#   if (!Test-Path -Path $DocsPath) { throw "$DocsPath is not present" }
#   $DocFileNames | % { $dfn = $_;
#     $dfp = Join-path $DocsPath $dfn
#     if (Test-Path -Path $dfp) {
#       write-verbose "DocFullPath $dfp already exists"
#     }
#     else {
#       if ($PSCmdlet.ShouldProcess("$dfp", 'Create')) {
#         write-verbose "Creating empty file $dfp, utf-8 encoding, no BOM"
#         [io.file]::WriteAllText($dfp, "", (new-object  System.Text.UTF8Encoding($false)))
#       }
#     }
#   }
# }


