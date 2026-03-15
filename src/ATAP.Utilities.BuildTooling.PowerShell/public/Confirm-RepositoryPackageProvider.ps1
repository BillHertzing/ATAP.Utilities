#############################################################################
#region Confirm-RepositoryPackageProvider
<#
.SYNOPSIS
Confirm that all the 3rd party tools and scripts needed to build, analyze, test, package and deploy both c# and powershell code are present, configured, and accessable,
.DESCRIPTION
This function looks for the presence of a Powershell Package Repository Provider
  - it expects to support three package providers Nuget, PSResourceGet, ChocolateyGet

.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS

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
Function Confirm-RepositoryPackageProvider {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'NoParameters')]
  param (
    [parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    [string] $PackageProviderName
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
    [string] $Encoding # Often found in the $PSDefaultParameterValues preference variable
  )

  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    # Set these as needed for debugging the script
    # Don't Print any debug messages to the console
    $DebugPreference = 'SilentlyContinue' # SilentlyContinue Continue
    # Don't Print any verbose messages to the console
    $VerbosePreference = 'Continue' # SilentlyContinue Continue
    Write-PSFMessage -Level Debug -Message "Starting Confirm-RepositoryPackageProvider; Encoding = $Encoding"
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    if (-not $(Get-PackageProvider -Name $PackageProviderName)) {
      # if it doesn't exists, install it
      if (-not $(Install-PackageProvider -Force -ForceBootstrap -Name $PackageProviderName)) {
        # ToDo better error logging
        Write-PSFMessage -Level Error -Message "Install-PackageProvider failed. PackageProviderName = $PackageProviderName" -Tag 'Validation'
        # Throw Error
        throw "Install-PackageProvider failed; PackageProviderName = $PackageProviderName"
      }
      # Import the newly registered provider into this session
      if (-not $(Import-PackageProvider -Force -ForceBootstrap -Name $PackageProviderName)) {
        # ToDo better error logging
        Write-PSFMessage -Level Error -Message "Import-PackageProvider failed. PackageProviderName = $PackageProviderName" -Tag 'Validation'
        # Throw Error
        throw "Import-PackageProvider failed; PackageProviderName = $PackageProviderName"
      }
    }
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
  }
  #endregion FunctionEndBlock
}
#endregion Confirm-RepositoryPackageProvider
#############################################################################

