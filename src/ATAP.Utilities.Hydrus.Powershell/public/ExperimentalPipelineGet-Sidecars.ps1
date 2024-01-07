#############################################################################
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
ToDo: Write examples
.ATTRIBUTION
ToDo: write text describing the ideas and codes that are attributed to others
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-Sidecars {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern'  )]
  param(
    [Parameter(Mandatory = $false,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $false
    )]
    # ToDo: replace with a c# type that contains all the known metadata fields
    [PSCustomObject[]]$obj
    , [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [switch] $PassThru
  )

  Begin {
    Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
    $originalPSBoundParameters = $PSBoundParameters # to allow debugging
    $sidecarSuffix = '.txt'
    function LocalGetSidecar {
      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
      # Get the tags ID from $o
      # get the tag's string from local cache
      # get the filename from $o
      # replace the file suffix with the parameter
      Write-Output $script:o
    }
    function InternalGetSidedcar {
      Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
      LocalGetSidecar
    }
  }

  process {
    foreach ($script:o in $obj) {
      InternalGetSidedcar
      "whertzing"
    }
  }
}
