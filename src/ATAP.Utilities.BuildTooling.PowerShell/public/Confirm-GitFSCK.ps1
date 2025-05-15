#############################################################################
#region Confirm-GitFSCK
<#
.SYNOPSIS
Confirm-GitFSCK is a PowerShell function that runs Git's fsck --full command across multiple Git repositories within a specified path.

.DESCRIPTION
This function is designed to automate the process of running Git's fsck --full command on multiple Git repositories within a specified directory. It is useful for checking the integrity of Git repositories and identifying potential issues.

.PARAMETER Path
The path to the directory containing the Git repositories to be checked. By default, it is set to 'C:\Dropbox\whertzing\GitHub'.

.PARAMETER OutPath
The path to the output file where the results of the Git fsck commands will be stored in JSON format. By default, it is set to '\\Utat022\fs\DailyReports\Confirm-GitFSCK-Results.txt'.

.INPUTS
None. This function does not take any input from the pipeline.

.OUTPUTS
The function does not output objects to the pipeline. Instead, it stores the results of the Git fsck commands in a JSON file specified by the OutPath parameter.

.EXAMPLE
Example 1:
Confirm-GitFSCK -Path 'C:\Path\To\GitRepos' -OutPath 'C:\Output\Results.json'

This example runs the Confirm-GitFSCK function on the specified path and saves the results in the specified JSON file.

.EXAMPLE
Example 2:
Confirm-GitFSCK

This example runs the Confirm-GitFSCK function with default parameters, checking Git repositories in the default path and saving results to the default output file.

.ATTRIBUTION
This function was inspired by the need to automate Git repository integrity checks. It includes error handling and logging features for enhanced reliability.

.LINK
You can find more information about Git fsck in the official Git documentation:
https://git-scm.com/docs/git-fsck

.LINK
For ideas related to PowerShell scripting and automation, you can visit the PowerShell documentation:
https://docs.microsoft.com/en-us/powershell/

.SCM
N/A
#>
Function Confirm-GitFSCK {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter()]
    [string]$Path = 'C:\Dropbox\whertzing\GitHub'
    , [string] $OutPath = '\\Utat022\fs\DailyReports\Confirm-GitFSCK-Results.txt'
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

    Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"
    Write-Verbose "path =$Path"
    Write-Verbose "OutPath = $OutPath"
    # validate path exists
    if (!(Test-Path -Path (Split-Path $Path -Parent))) { throw "$Path was not found" }

    # Output tests
    $outDir = $(Split-Path $OutPath -Parent)
    if (-not (Test-Path -Path $outDir -PathType Container)) {
      throw "$outDir is not a directory"
    }
    # Validate that the $OutPath is writable
    $testOutFn = $outDir + 'test.txt'
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

    $datestr = Get-Date -Format 'yyyy/MM/dd:HH.mm' -AsUTC
    $dateKeyedHash = if (Test-Path -Path $OutPath) { Get-Content $OutPath | ConvertFrom-Json -asHash } else { @{} }

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
    $dateKeyedHash[$datestr ] =
    Get-ChildItem -Path $Path -r -d 1 | Where-Object { $_.psiscontainer } | ForEach-Object { $dir = $_;
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
    }

    $dateKeyedHash | ConvertTo-Json | Set-Content -Path $OutPath
  }
  #endregion FunctionEndBlock
}
#endregion Confirm-GitFSCK
#############################################################################
