#############################################################################
#region Set-RepositoryPackageSources
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
Function Set-RepositoryPackageSources {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'NoParameters' )]
  param (
    # Chocolatey install location
    [Parameter(ParameterSetName = 'WithParameters')]
    # [ValidateScript({ Test-Path $_ })]
    [string] $Dummy
  )

  #endregion FunctionParameters
  BEGIN {
    # $DebugPreference = 'SilentlyContinue'
    Write-PSFMessage -Level Debug -Message "Starting Set-RepositoryPackageSources. PsCmdlet.ParameterSetName = $($PsCmdlet.ParameterSetName)"
  }
  END {
    # ToDo: move the registration of repository locations into a seperate function. Invoke it on container or server creation / maintenance
    # Register repository locations
     ('NuGet', 'PowershellGet', 'Chocolatey') | ForEach-Object { $ProviderName = $_
      # Validate each package provider is installed, else install it
      if (-not $(Get-PackageProvider -Name $ProviderName)) {
        if (-not $(Find-PackageProvider -Name $ProviderName)) {
          # ToDo better error logging
          Write-PSFMessage -Level Error -Message "Provider Not Found; ProviderName = $ProviderName"
          # Throw Error
          throw "Provider Not Found; ProviderName = $ProviderName"
        }
        else { Install-PackageProvider -Name $ProviderName -ForceBootstrap }
      }
      ('Filesystem', 'WebServerQualityAssurance', 'WebServerProduction') | ForEach-Object { $PackageSource = $_
        ('Development', 'QualityAssurance', 'Production') | ForEach-Object { $Lifecycle = $_
          $PackageSourceID = $ProviderName + $PackageSource + $Lifecycle
          if (!$(Get-PackageSource -Name $PackageSourceID -ErrorAction SilentlyContinue)) {
            switch -regex ($PackageSourceID) {
              'NuGetFilesystemDevelopment|NuGetFilesystemQualityAssurance|NuGetFilesystemProduction|PowerShellGetFilesystemDevelopment|PowerShellGetFilesystemQualityAssurance|PowerShellGetFilesystemProduction' {
                # ToDo add try/catch error handling
                Set-PackageSource -Name $PackageSourceID -ForceBootstrap -Trusted -Location $global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']][$PackageSourceID]
                break
              }
              'NuGetQualityAssuranceWebServerDevelopment' {
                break
              }
              'NuGetQualityAssuranceWebServerQualityAssurance' {
                break
              }
              'NuGetQualityAssuranceWebServerProduction' {
                break
              }
              'NuGetProductionWebServerDevelopment' {
                break
              }
              'NuGetProductionWebServerQualityAssurance' {
                break
              }
              'NuGetProductionWebServerProduction' {
                break
              }
              'PowershellGetQualityAssuranceWebServerDevelopment' {
                break
              }
              'PowershellGetQualityAssuranceWebServerQualityAssurance' {
                break
              }
              'PowershellGetQualityAssuranceWebServerProduction' {
                break
              }
              'PowershellGetProductionWebServerDevelopment' {
                break
              }
              'PowershellGetProductionWebServerQualityAssurance' {
                break
              }
              'PowershellGetProductionWebServerProduction' {
                break
              }
              'ChocolateyFilesystemDevelopment' {
                break
              }
              'ChocolateyFilesystemQualityAssurance' {
                break
              }
              'ChocolateyFilesystemProduction' {
                break
              }
              'ChocolateyQualityAssuranceWebServerDevelopment' {
                break
              }
              'ChocolateyQualityAssuranceWebServerQualityAssurance' {
                break
              }
              'ChocolateyQualityAssuranceWebServerProduction' {
                break
              }
              'ChocolateyProductionWebServerDevelopment' {
                break
              }
              'ChocolateyProductionWebServerQualityAssurance' {
                break
              }
              'ChocolateyProductionWebServerProduction' {
                break
              }
            }

          }
        } } }


  }
}
#############################################################################


