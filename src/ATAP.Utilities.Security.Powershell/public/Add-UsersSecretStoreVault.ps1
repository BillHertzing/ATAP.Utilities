#############################################################################
#region Add-UsersSecretStoreVault
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
Function FunctionNameReplacementPattern {
  #region Parameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSetNameReplacementPattern')]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
    [ValidateScript({ Test-Path $_ })]
    [string] $Path
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [string] $Encoding
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
    [switch] $Force
  )
  #endregion Parameters
  #region BeginBlock
  BEGIN {
    #$DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion EndBlock
}
#endregion FunctionNameReplacementPattern
#############################################################################


