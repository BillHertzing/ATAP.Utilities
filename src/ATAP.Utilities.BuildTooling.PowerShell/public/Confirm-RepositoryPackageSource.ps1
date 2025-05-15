#############################################################################
#region Confirm-RepositoryPackageSource
<#
.SYNOPSIS
Confirm that all the 3rd party tools and scripts needed to build, analyze, test, package and deploy both c# and powershell code are present, configured, and accessable,
.DESCRIPTION
This function looks for the presence of Powershell Package Sources
  - deploy packages to internal and external location, to three public location (Nuget, PowershellGet, ChocolateyGet)

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
Function Confirm-RepositoryPackageSource {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'NoParameters')]
  param (
    [parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True, Mandatory = $true)]
    #ToDo: make this a Powershell class
    [string] $RepositoryPackageSourceName
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
    [string] $Encoding # Often found in the $PSDefaultParameterValues preference variable
  )

  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    # Set these as needed for debugging the script
    # Don't Print any debug messages to the console
    # $DebugPreference = 'SilentlyContinue' # SilentlyContinue Continue
    # Don't Print any verbose messages to the console
    # $VerbosePreference = 'Continue' # SilentlyContinue Continue
    Write-PSFMessage -Level Debug -Message "Starting Confirm-RepositoryPackageSource; Encoding = $Encoding"

  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    if (-not $(Get-PackageSource -Name $RepositoryPackageSourceName)) {
      # if it doesn't exists, register it
      # ToDo - require an admin role and elevated permissions to register one
      # ToDo : get ProviderName and provider repositorylifecycle from the TBD powershell class
      $providerName = ''
      $ProviderLifecycle = ''
      switch -regex ($RepositoryPackageSourceName) {
        'nuget' {
          $providerName = 'NuGet'
          break
        }
        'PowershellGet' {
          $providerName = 'PowershellGet'
          break
        }
        'ChocolateyGet' {
          $providerName = 'ChocolateyGet'
          break
        }
      }
      switch -regex ($RepositoryPackageSourceName) {
        'Filesystem' {
          $ProviderLifecycle = 'Filesystem'
          break
        }
        'QualityAssuranceWebServer' {
          $ProviderLifecycle = 'QualityAssuranceWebServer'
          break
        }
        'ProductionWebServer' {
          $ProviderLifecycle = 'ProductionWebServer'
          break
        }
      }


      Write-PSFMessage -Level Debug -Message "global:configRootKeys['PackageRepositoriesCollectionConfigRootKey'] = $(Write-HashIndented $global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']])"
      Write-PSFMessage -Level Debug -Message "providerName = $providerName;ProviderLifecycle = $ProviderLifecycle"
      Write-PSFMessage -Level Debug -Message "RepositoryPackageSourceName = $RepositoryPackageSourceName; Location = $($global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']][$RepositoryPackageSourceName])"
      "$($global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']][$RepositoryPackageSourceName])"
      if (-not $(Register-PackageSource -Force -ForceBootstrap -Trusted -Name $RepositoryPackageSourceName -ProviderName $providerName -Location $($global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']][$RepositoryPackageSourceName]))) {
        # ToDo better error logging
        Write-PSFMessage -Level Error -Message "RepositoryPackageSourceName Not Found; RepositoryPackageSourceName = $RepositoryPackageSourceName" -Tag 'Validation'
        # Throw Error
        throw "RepositoryPackageSourceName Not Found; RepositoryPackageSourceName = $RepositoryPackageSourceName"
      }
    }

  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    # $str = nuget locals all -list
    # $dateKeyedHash[$datestr ] = $str
    # $dateKeyedHash | ConvertTo-Json | Set-Content -Path $OutPath
  }
  #endregion FunctionEndBlock
}
#endregion Confirm-RepositoryPackageSource
#############################################################################

