#############################################################################
#region Confirm-Tools
<#
.SYNOPSIS
Confirm that all the 3rd party tools and scripts needed to build, analyze, test, package and deploy both c# and powershell code are present, configured, and accessable,
.DESCRIPTION
This function looks for the presence of tools that can compile and interpret c# and Powershell code (text files to executable production code), create documenation from code, generate class diagrams from code, integrate the generated dart with the markdown format, suports draw.io engineering drawings,
tools that provide message queing, tools that provide Source Code Management (SCM), SQL Server database and Neo4j database, tools for database SCM (Flyway from Redhat)
tools that create the deployment package, tools that deploy the packages, to three public location (PSGallery, Nuget, and Chocolotey)
.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
Environment variables drive the action that this Cmdlet takes.
Machine and container nodes are grouped and assigned capabilities (roles).
Roles imply a promise that certains tools will be avaialable in the environments that certain actions can occur.

Environments Production, Test, and Development are the 1st roots of the Environment Variables.
he public locations, private locations, and the exact composition of the machine code and documentation package,
  make up the full exposition of every combination of environment variables.



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
    if (-not (Test-Path -Path $settings.OutDir -PathType Container)) {
      throw "$settings.OutDir is not a directory"
    }
    # Validate that the $Settings.OutDir is writable
    $testOutFn = $settings.OutDir + 'test.txt'
    try { New-Item $testOutFn -Force -type file >$null
    }
    catch { # if an exception ocurrs
      # handle the exception
      $where = $PSItem.InvocationInfo.PositionMessage
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      #Log('Error', "new-item $testOutFn -force -type file failed with $FailedItem : $ErrorMessage at $where.");
      Throw "new-item $testOutFn -force -type file failed with $FailedItem : $ErrorMessage at $where."
    }
    # Remove the test file
    Remove-Item $testOutFn -ErrorAction Stop

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
    $dateKeyedHash | ConvertTo-Json | Set-Content -Path $OutPath
  }
  #endregion FunctionEndBlock
}
#endregion Confirm-Tools
#############################################################################

