#############################################################################
#region Get-JenkinsEnvSettings
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

ToDo! - Insert PlantUML diagram here how this Jenkins Powershell script fits into the Jenkins pipeline
Write-Verbose 'Starting Get-JenkinsEnvSettings'

.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 3 of using this function
.ATTRIBUTION

.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-JenkinsEnvSettings {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"
    # default values for settings
    $settings = @{
      RIDList                    = $[]
      RuntimeTargets             = $[]
      EnableBuild                = $true
      EnableIncrementalBuild     = $false
      EnableXUnitTests           = $true
      EnableCodeGraphAnalysis    = $true
      PathForDevLogs             = DefaultPathForDevLogs
      CmdForBuild                = $Defaults.CmdForBuild
      InBusinessName1FilePattern = 'statistics'
      InBusinessName2FilePattern = 'unused'
      OutDir                     = '.'
      OutFNBusinessName1         = 'OutName1-' + (Get-Date).ToString('yyyyMMdd') + '.cfg'
      OutFNBusinessName2         = 'OutName2-' + (Get-Date).ToString('yyyyMMdd') + '.cfg'
    }
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
    if (-not(Get-ChildItem $settings.InDir | Where-Object { $_ -match $settings.InBusinessName1FilePattern })) { throw 'there are no files matching {0} in directory {1}' -f $settings.InBusinessName1FilePattern, $settings.InDir }
    #if (-not(ls $settings.InDir | ?{$_ -match $settings.InBusinessName2FilePattern})) {throw "there are no files matching {0} in directory {1}" -f $settings.InBusinessName2FilePattern,$settings.InDir}

    # Output tests
    if (-not (Test-Path -Path $settings.OutDir -PathType Container)) {
      throw "$settings.OutDir is not a directory"
    }
    # Validate that the $Settings.OutDir is writable
    $testOutFn = $settings.OutDir + 'test.txt'
    try { New-Item $testOutFn -Force -type file >$null
    } catch { # if an exception occurs
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
    $InDataFile = (@(Get-ChildItem $settings.InDir | Where-Object { $_ -match $settings.InBusinessName1FilePattern } | Sort-Object -Descending -Property 'LastWriteTime')[0]).Fullname

    # Absolute path to copy files to and create folders in
    $absolutePath = @($copyTo + '/App_Config/Include')
    # Set paths we will be copy files from
    $featureDirectory = Join-Path $solutionDirectory '/Feature/*/App_Config/Include'
    $foundationDirectory = Join-Path $solutionDirectory '/Foundation/*/App_Config/Include'

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
    $path = $absolutePath
    Write-Verbose -Message "Ending $($MyInvocation.MyCommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Get-JenkinsEnvSettings
#############################################################################

