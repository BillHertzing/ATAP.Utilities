#############################################################################
#region Get-ClonedAndModifiedHashtable
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Path
  Specifies the path where searching should start. May be a string or an array in the form (p1[,p2][,p3]...)
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
Function Get-ClonedAndModifiedHashtable {
  Param(
    [Parameter(Mandatory = $true)]
    [hashtable]$source,

    [hashtable]$modifications
  )

  $Clone = $source.Clone()
  foreach ($Key in $modifications.Keys) {
    $Clone[$Key] = $modifications[$Key]
  }
  return $Clone
}

#endregion Get-ClonedAndModifiedHashtable
#############################################################################


