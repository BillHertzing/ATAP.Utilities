#############################################################################
#region Get-ClonedAndModifiedHashtable
<#
.SYNOPSIS
Use the serializer to create an independent copy of an object, then modify that copy. with the hashtables of the modifications
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER source
  The source hashtable
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
[Deep copying a PSObject](https://stackoverflow.com/questions/9204829/deep-copying-a-psobject), the answer supplied by Justin Grote
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
using namespace System.Management.Automation
Function Get-ClonedAndModifiedHashtable {
  Param(
    [Parameter(Mandatory = $true)]
    [hashtable]$source,

    [hashtable[]]$modifications
  )

  # ToDo: turn this into a cmdlet capable of accepting multiple modifications via the pipeline
  $clone = [psserializer]::Deserialize(
    [psserializer]::Serialize(
      $source
    )
  )
  for ($modificationsIndex = 0; $modificationsIndex -lt $modifications.Count; $modificationsIndex++) {
    $modification = $modifications[$modificationsIndex]
    $clonedModification = [psserializer]::Deserialize(
      [psserializer]::Serialize(
        $modification
      )
    )
    foreach ($Key in $clonedModification.Keys) {
      $Clone[$Key] = $clonedModification[$Key]
    }
  }

  return $Clone
}

#endregion Get-ClonedAndModifiedHashtable
#############################################################################


