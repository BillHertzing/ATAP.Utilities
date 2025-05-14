#############################################################################
#region Remove-ObjAndBinSubdirs
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
Function Remove-ObjAndBinSubdirs {
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
    $dirsToDelete = 'obj', 'bin'
    Write-Verbose "path = $path"
    # validate path exists
    if (!(Test-Path -Path $path)) { throw "$path was not found" }
    Write-Verbose "Removing obj and bin subdirs recursively below $path"
    # build alternation (OR) pattern for directory names as returned by gci, anchored to the end : (\\obj|\\bin)$
    $MatchRegex = '(' + (($dirstodelete | ForEach-Object { '\\' + $_ }) -Join ('|')) + ')$'
    $pathsToDelete = Get-ChildItem -Recurse -Directory $path | Where-Object { $_.psISContainer -and ($_.fullname -match $MatchRegex) }
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    Write-Verbose "Removing $($pathsToDelete.Length) directories:  $($pathsToDelete -join [environment]::NewLine)"
    $pathsToDelete | ForEach-Object {
      $dirToDelete = $_
      if ($PSCmdlet.ShouldProcess("$dirToDelete", 'remove-item -recurse -force ')) {
        Remove-Item -Recurse -Force $dirToDelete -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference
        #write-verbose "remove-item -recurse -force $dirToDelete -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference"
      }
    }
  }
  #endregion FunctionEndBlock
}
#endregion Remove-ObjAndBinSubdirs
#############################################################################
