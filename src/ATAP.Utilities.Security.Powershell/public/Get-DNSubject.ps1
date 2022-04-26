#############################################################################
#region Get-DNSubject
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

function Get-DNSubject {
  param(
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $CN
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $emailAddress
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $SubjectReplacementPattern
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    $SubjectAlternativeNameReplacementPattern
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $Country
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $StateOrTerritory
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $Locality
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $Organization
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $OrganizationUnit
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string[]]$KeyUseage
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    $ExtendedKeyUseage
  )
  $propertyHash =
  @{
    AsFileName     = $SubjectReplacementPattern -f $CN, $OrganizationUnit, $Organization, $StateOrTerritory, $Locality, $Country
    AsParameter    = "/CN=$CN/OU=$OrganizationUnit/O=$Organization/L=$Locality/ST=$StateOrTerritory/C=$Country"
    SANAsParameter = '"' + "subjectAltName=$EmailAddress" + '"'
    SANAsFilename  = "$SubjectAlternativeNameReplacementPattern -f $EmailAddress"
  }
  # Add optional properties
  if ($KeyUseage) {
    $propertyHash['KeyUseage'] = "keyUsage=$($KeyUseage -join ',')"
  }
  if ($ExtendedKeyUseage) {
    $propertyHash['ExtendedKeyUseage'] = "extendedKeyUsage=$($ExtendedKeyUseage -join ',')"
  }
  # return the hash as a PSObject
  New-Object PSObject -Property $propertyHash
}

#endregion Get-DNSubject
#############################################################################
