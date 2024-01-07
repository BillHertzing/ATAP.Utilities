#############################################################################
#region FunctionName
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE
ToDo: write Help For example 1 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-BookmarksToTagged {
#region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter()]
    [string] $outFn = './Taggedbookmarks.txt'
    ,[parameter()]
    [string] $tagFn = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\tags.txt'
  )
#endregion FunctionParameters
#region FunctionBeginBlock
########################################
BEGIN {
  Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
  # ToDo: Validate $outFn is writeable
  write-verbose "outFn = $outFn"
  # validate $outfn path exists
  if (!(test-path -Path $outfn)) { throw "$outfn was not found" }
  
  # get a list of tagged bookmarks from persistence
  
  # get current bookmarks from chrome
  write-verbose -Message "Getting list of bookmarks"
  $bookmarkList = Get-GoogleChromeBookmarks
  
  # get a list of tags from persistence
  write-verbose -Message "Getting list of tags"
  $tagList = (gc $tagFn) -split [environment]::NewLine
  
   # build alternation (OR) pattern for tags
  $tagsMatchRegex = "(" + (($tagList | ForEach-Object{$_}) -Join('|')) + ")$"
}
#endregion FunctionBeginBlock

#region FunctionProcessBlock
########################################
PROCESS {
# iterate over each bookmark in the bookmarkList
$bookmarkList | %{ $bookmark = $_
  # match name to tags
  # match folder to tags
  # match url to tags
  # sort tags and remove duplicates
  
}
}
#endregion FunctionProcessBlock

#region FunctionEndBlock
########################################
END {
  Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  return $results
}
#endregion FunctionEndBlock
}
#endregion FunctionName
#############################################################################

#############################################################################
