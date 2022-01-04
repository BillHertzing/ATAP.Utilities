#############################################################################
#region Get-TableNamesFromGCode
<#
.SYNOPSIS
Reads .cs Files and builds an initial SQL Create Table code block
.DESCRIPTION
Gets all the .cs files in the source directory, and outputs a 'create table' sql block (per template) for each class and interface
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
Function Get-TableNamesFromGCode {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter()]
    [string] $path = './'
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true, )]
    [ValidateNotNullorEmpty()]
    [string] $tableCreateTemplate
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
    # Create or reuse a directory to place the table create scripts into
    $tmpOutputPath = join-path $ENV:tmp '/TableNamesFromGCode'
    # Validate the path is correct for the G files
    $path = join-path $global:DropBoxBaseDir 'ATAP.Utilities/src/ATAP.Utilities.GenerateProgram'
    Write-Verbose "Validating $path"
    if (!(test-path $path)) {
       Write-Error "$path does not exist"
    }
    # List of cs files starting with 'G'
    $generatedCSharpFiles = gci g*.cs
    Write-Verbose "generatedCSharpFiles = $generatedCSharpFiles -join ';'"
    # list of table names corresponding to G files
    $tableNamesForGeneratedCSharpFiles = $generatedCSharpFiles.TrimEnd(".cs")
    Write-Verbose "tableNamesForGeneratedCSharpFiles = $tableNamesForGeneratedCSharpFiles -join ';'"
# read each G file, get any AutoProperties starting with G
    # Update the template create scripts with foreign key relationships among this set of tables

    if ((test-path $path) -AND ($path -match 'nuget')) {
      if ($PSCmdlet.ShouldProcess("$path", "-Recurse -Force -Path $path -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference ")) {
        Remove-Item -Recurse -Force -Path $path -WhatIf:$WhatIfPreference -Verbose:$Verbosepreference
      }
    } else {
       Write-Output "Either $path does not exist or $path does not contain the case-insensitive substring nuget!"
    }
    # write all the Create Table scripts
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Get-TableNamesFromGCode
#############################################################################

