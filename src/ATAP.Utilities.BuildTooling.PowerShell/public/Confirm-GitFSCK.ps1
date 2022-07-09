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

    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
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
