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
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
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
	   Write-Verbose "Removing ($ENV:AppData)\Local\NuGet\v3-cache"
    if ($PSCmdlet.ShouldProcess("($ENV:AppData)\Local\NuGet\v3-cache", 'Delete')) {
      Write-Host "really would delete ($ENV:AppData)\Local\NuGet\v3-cache"
    }
    Write-Verbose "Removing ($ENV:USERPROFILE)\.nuget\packages"
    if ($PSCmdlet.ShouldProcess("($ENV:USERPROFILE)\.nuget\packages", 'Delete')) {
      Write-Host "really would delete ($ENV:USERPROFILE)\.nuget\packages"
    }
    Write-Verbose "Removing ($ENV:AppData)\Local\Temp\NuGetScratch"
    if ($PSCmdlet.ShouldProcess("($ENV:AppData)\Local\Temp\NuGetScratch", 'Delete')) {
      #				write-host "really would delete ($ENV:\AppData)\Local\Temp\NuGetScratch"
    }

    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Clear-NuGetCaches
#############################################################################
