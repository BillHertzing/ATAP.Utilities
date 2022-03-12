#############################################################################
#region Confirm-Tools
<#
.SYNOPSIS
Confirm that all the 3rd party tools and scripts needed to build, analyze, test, package and deploy both c# and powershell code are present, configured, and accessable,
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
Function Confirm-Tools {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter()]
    [string] $OutPath = '\\Utat022\fs\DailyReports\Confirm-Tools-Results.txt'
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    # Set these as needed for debugging the script
    # Don't Print any debug messages to the console
    #$DebugPreference = 'SilentlyContinue'
    # Don't Print any verbose messages to the console
    $VerbosePreference = 'Continue' # SilentlyContinue Continue
    Write-Debug -Message "Starting $($MyInvocation.Mycommand)"
    Write-Verbose "OutPath = $OutPath"
    # Output tests
    $OutDir = Split-Path $OutPath -Parent
    if (-not (Test-Path -Path $OutDir -PathType Container)) { throw "$OutDir is not a directory" }
    # Validate that the $Settings.OutDir is writable
    $testOutFn = Join-Path $OutDir 'test.txt'
    try { New-Item $testOutFn -Force -type file >$null }
    catch {
      #Log('Error', "Can't write to file $testOutFn");
      throw "Can't write to file $testOutFn"
    }
    # Remove the test file
    Remove-Item $testOutFn

    $datestr = Get-Date -AsUTC -Format 'yyyy/MM/dd:HH.mm'

    # Read in the contents of the last $OutPath file as a hash
    $dateKeyedHash = if (Test-Path -Path $OutPath) { gc $OutPath | ConvertFrom-Json -asHash } else { @{}
    }

    Write-Verbose 'Validating tools and configurations are present'
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
    $str = nuget locals all -list
    $dateKeyedHash[$datestr ] = $str
    $dateKeyedHash | ConvertTo-Json | set-content -path $OutPath
  }
  #endregion FunctionEndBlock
}
#endregion Confirm-Tools
#############################################################################

