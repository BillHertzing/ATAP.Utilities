#############################################################################
#region Clear-NuGetCaches
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
Function Clear-NuGetCaches {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter()]
    [string] $path = './'
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"
    Write-Verbose -Message "Caches may be locked! Stop any IDEs or CI processes. )"
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    #
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    $path = join-path $env:USERPROFILE '.nuget/packages'
    Write-Verbose "Removing $path"
    if ((test-path $path) -AND ($path -match 'nuget')) {
      if ($PSCmdlet.ShouldProcess("$path", "Remove-Item -Recurse -Force -Path $path -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference ")) {
        Remove-Item -Recurse -Force -Path $path -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference
      }
    } else {
       Write-Output "Either $path does not exist or $path does not contain the case-insensitive substring nuget!"
    }
    $path = join-path $ENV:tmp 'NuGetScratch'
    Write-Verbose "Removing $path"
    if ((test-path $path) -AND ($path -match 'nuget')) {
      if ($PSCmdlet.ShouldProcess("$path", "Remove-Item -Recurse -Force -Path $path -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference ")) {
        Remove-Item -Recurse -Force -Path $path -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference
      }
    } else {
       Write-Output "Either $path does not exist or $path does not contain the case-insensitive substring nuget!"
    }
    $path = join-path $ENV:LOCALAPPDATA 'NuGet/v3-cache'
    Write-Verbose "Removing $path"
    if ((test-path $path) -AND ($path -match 'nuget')) {
      if ($PSCmdlet.ShouldProcess("$path", "Remove-Item -Recurse -Force -Path $path -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference ")) {
        Remove-Item -Recurse -Force -Path $path -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference
      }
    } else {
       Write-Output "Either $path does not exist or $path does not contain the case-insensitive substring nuget!"
    }
    Write-Verbose -Message "Ending $($MyInvocation.MyCommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Clear-NuGetCaches
#############################################################################
