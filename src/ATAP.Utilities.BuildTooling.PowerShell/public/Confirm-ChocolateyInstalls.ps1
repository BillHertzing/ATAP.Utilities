#############################################################################
#region Confirm-ChocolateyInstalls
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
Function Confirm-ChocolateyInstalls {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'NoParameters' )]
  param (
    # Chocolatey install location
    [Parameter(ParameterSetName = 'WithParameters')]
    [ValidateScript({ Test-Path $_ })]
    [string] $ChocolateyInstalls
  )

  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    # $DebugPreference = 'SilentlyContinue'
    Write-Debug "Starting $($MyInvocation.Mycommand)"
    Write-Debug "PsCmdlet.ParameterSetName = $($PsCmdlet.ParameterSetName)"

    $binDirList = $null
    $libDirList = $null
    if ( $PsCmdlet.ParameterSetName -eq 'NoParameters') {
      if (-not (Test-Path -Path [Environment]::GetEnvironmentVariable($global:configRootKeys['ChocolateyInstallDirConfigRootKey']))) {
        #Log('Error',"Confirm-ChocolateyInstalls failed, directory does not exist. ChocolateyInstallDir = $([Environment]::GetEnvironmentVariable($global:configRootKeys['ChocolateyInstallDirConfigRootKey']))")
        throw "Confirm-ChocolateyInstalls failed, directory does not exist. ChocolateyInstallDir = $([Environment]::GetEnvironmentVariable($global:configRootKeys['ChocolateyInstallDirConfigRootKey']))"
      }
    }
    Write-Verbose "Ending $($MyInvocation.Mycommand)"
    # return a results object
    $results
  }
  END {
    $p_ncat016 = Get-Content \dropbox\ChocolateyPackageListBackup\ncat016\packages.config
    $p_utat022 = Get-Content \dropbox\ChocolateyPackageListBackup\utat022\packages.config
    $p_utat01 = Get-Content \dropbox\ChocolateyPackageListBackup\utat01\packages.config

    $c_ncat016_utat01 = Compare-Object $p_ncat016 $p_utat01 -IncludeEqual | ? { $_.sideIndicator -eq '==' }
    $c_ncat016_utat022 = Compare-Object $p_ncat016 $p_utat022 -IncludeEqual | ? { $_.sideIndicator -eq '==' }
    $c_utat01_utat22 = Compare-Object $p_utat01 $p_utat022 -IncludeEqual | ? { $_.sideIndicator -eq '==' }

    $allcommon = Compare-Object $c_ncat016_utat01 $c_ncat016_utat022 -IncludeEqual | ? { $_.sideIndicator -eq '==' }
    $CommonOnlyToncat016_utat01 = Compare-Object $c_ncat016_utat01 $p_utat022 -IncludeEqual | ? { $_.sideIndicator -eq '>=' }

    # Are the packages recorded by CLPB present in the two Lists?
  }
  #endregion FunctionEndBlock
}
#endregion FunctionName
#############################################################################


