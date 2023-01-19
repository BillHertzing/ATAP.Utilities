#############################################################################
#region Confirm-RepositoryPackageProvider
<#
.SYNOPSIS
Confirm that all the 3rd party tools and scripts needed to build, analyze, test, package and deploy both c# and powershell code are present, configured, and accessable,
.DESCRIPTION
This function looks for the presence of Powershell Package Repository Sources
  - deploy packages to internal and external location, to three public location (PowershellGet, Nuget, and Chocolotey)

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
    [string] $ProviderName
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
    if (-not $(Get-PackageProvider -Name $ProviderName)) {
      # if it doesn't exists, install it
      if (-not $(Install-PackageProvider -Force -ForceBootstrap -Name $ProviderName)) {
        # ToDo better error logging
        Write-PSFMessage -Level Error -Message "Install-PackageProvider failed. ProviderName = $ProviderName" -Tag 'Validation'
        # Throw Error
        throw "Install-PackageProvider failed; ProviderName = $ProviderName"
      }
      # Import the newly registered provider into this session
      if (-not $(Import-PackageProvider -Force -ForceBootstrap -Name $ProviderName)) {
        # ToDo better error logging
        Write-PSFMessage -Level Error -Message "Import-PackageProvider failed. ProviderName = $ProviderName" -Tag 'Validation'
        # Throw Error
        throw "Import-PackageProvider failed; ProviderName = $ProviderName"
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

