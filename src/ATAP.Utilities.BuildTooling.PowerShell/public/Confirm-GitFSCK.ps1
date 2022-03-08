#############################################################################
#region Confirm-GitFSCK
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
Function Confirm-GitFSCK {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter()]
    [string] $path = 'C:\Dropbox\whertzing\GitHub'
    ,[string] $OutDir = './'
    ,[string] $OutFile = 'Confirm-GitFSCK-Results.txt'
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

    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    Write-Verbose "path = $path"
    Write-Verbose "OutDir = $OutDir"
    Write-Verbose "OutFile = $OutFile"
    # validate path exists
    if (!(Test-Path -Path $path)) { throw "$path was not found" }
      # Output tests
  if (-not (test-path -path $OutDir -pathtype Container)) {throw "$OutDir is not a directory"}
  # Validate that the $Settings.OutDir is writable
  $testOutFn = $OutDir + 'test.txt'
  try {new-item $testOutFn -force -type file >$null}
  catch {
    #Log('Error', "Can't write to file $testOutFn"); 
    throw "Can't write to file $testOutFn"
  }
  # Remove the test file
  Remove-Item $testOutFn

    Write-Verbose 'Running GitFSCK across multiple repositories'
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
    Get-ChildItem -Path $path -r -d 1 | Where-Object { $_.psiscontainer } | ForEach-Object { $dir = $_;
      Get-ChildItem $_ | Where-Object { $_.fullname -match '\.git$' } | Sort-Object -uniq | ForEach-Object {
        Push-Location
        $dir = $_
        Set-Location $dir
        if ($PSCmdlet.ShouldProcess("$dir", 'git fsck --full')) {
          Write-Verbose "git fsk at $dir"
          git fsck --full
        }
        Pop-Location 
      }
    } | Set-Content -path (Join-Path $OutDir $OutFile)
  }
  #endregion FunctionEndBlock
}
#endregion Confirm-GitFSCK
#############################################################################
