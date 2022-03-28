#############################################################################
#region Set-LineEndings
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
    # set-eol.ps1
    # Change the line endings of a text file to: Windows (CR/LF), Unix (LF) or Mac (CR)
    # Requires PowerShell 3.0 or greater

    # Syntax
    #       ./set-eol.ps1 -lineEnding {mac|unix|win} -file FullFilename

    #     mac, unix or win  : The file endings desired.
    #     FullFilename      : The full pathname of the file to be modified.

    #     ./set-eol win "c:\demo\data.txt"
.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
ToDo: write Help For the function's inputs
.OUTPUTS
ToDo: write Help For the function's outputs
.EXAMPLE

$files = Get-Content $filelist
$files | ForEach-Object { $f = $_
  set-eol $lineEnding (Join-Path $basepath $f)
.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
  attribution to https://ss64.com/ps/syntax-set-eol.html

.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Set-LineEndings {
  #region FunctionParameters
  param (

    [CmdletBinding(SupportsShouldProcess = $true)]
    [string]$filelist
    , [string]$basepath
    , [ValidateSet('mac', 'unix', 'win')]
    [string]$lineEnding = 'unix'
    # Default is utf-8 without a Byte-Order-Mark (BOM)
    , [System.Text.Encoding]$encoding = (New-Object System.Text.UTF8Encoding($false))

  )

  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    $DebugPreference = 'Continue'

    # default values for settings
    $settings = @{
      InDir                      = '..\Data'
      InBusinessName1FilePattern = 'statistics'
      InBusinessName2FilePattern = 'unused'
      OutDir                     = '.'
      OutFNBusinessName1         = 'OutName1-' + (Get-Date).ToString('yyyyMMdd') + '.cfg'
      OutFNBusinessName2         = 'OutName2-' + (Get-Date).ToString('yyyyMMdd') + '.cfg'
    }

    # Things to be initialized after settings are processed
    if ($InDir) { $Settings.InDir = $InDir }
    if ($InFn1) { $Settings.InBusinessName1FilePattern = $InFn1 }
    if ($InFn2) { $Settings.InBusinessName2FilePattern = $InFn2 }
    if ($OutDir) { $Settings.OutDir = $OutDir }
    if ($OutFn1) { $Settings.OutFNBusinessName1 = $OutFn1 }
    if ($OutFn2) { $Settings.OutFNBusinessName2 = $OutFn2 }
    if ($OutFn3) { $Settings.OutFnOnDemandRules = $OutFn3 }

    # Turn any input file name patterns that are of the form (..[,..]*) into arrays
    if ($settings.InBusinessName1FilePattern -match '^\(.*\)$') { $settings.InBusinessName1FilePattern = $settings.InBusinessName1FilePattern -replace ',', '|' }
    if ($settings.InBusinessName2FilePattern -match '^\(.*\)$') { $settings.InBusinessName2FilePattern = $settings.InBusinessName2FilePattern -replace ',', '|' }

    # In and out directory and file validations
    if (-not (Test-Path -Path $settings.InDir -PathType Container)) { throw "$settings.InDir is not a directory" }
    if (-not(ls $settings.InDir | ? { $_ -match $settings.InBusinessName1FilePattern })) { throw 'there are no files matching {0} in directory {1}' -f $settings.InBusinessName1FilePattern, $settings.InDir }
    #if (-not(ls $settings.InDir | ?{$_ -match $settings.InBusinessName2FilePattern})) {throw "there are no files matching {0} in directory {1}" -f $settings.InBusinessName2FilePattern,$settings.InDir}

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

    $OutFnName1 = Join-Path $settings.OutDir $settings.OutFnBusinessName1
    $OutFnName2 = Join-Path $settings.OutDir $settings.OutFnBusinessName2

    #Get the latest of each file that matches an alternate
    $InDataFile = (@(ls $settings.InDir | ? { $_ -match $settings.InBusinessName1FilePattern } | sort -Descending -Property 'LastWriteTime')[0]).Fullname

    $results = @{}
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
    # Convert the friendly name into a PowerShell EOL character
    Switch ($lineEnding) {
      'mac' { $eol = "`r" }
      'unix' { $eol = "`n" }
      'win' { $eol = "`r`n" }
    }

    # Replace CR+LF with LF
    $text = [IO.File]::ReadAllText($file) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($file, $text, $encoding)

    # Replace CR with LF
    $text = [IO.File]::ReadAllText($file) -replace "`r", "`n"
    [IO.File]::WriteAllText($file, $text, $encoding)

    #  At this point all line-endings should be LF.

    # Replace LF with intended EOL char
    if ($eol -ne "`n") {
      $text = [IO.File]::ReadAllText($file) -replace "`n", $eol
      [IO.File]::WriteAllText($file, $text, $encoding)
    }
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Set-LineEndings
#############################################################################
