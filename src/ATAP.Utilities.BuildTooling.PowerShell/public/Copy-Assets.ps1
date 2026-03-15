#############################################################################
#region Copy-Assets
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

Write-Verbose 'Starting Copying Foundation Files'
Copy-Assets -directoryBase $foundationDirectory
Write-Verbose 'Starting Copying Feature Files'
Copy-Assets -directoryBase $featureDirectory

.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 2 of using this function
.ATTRIBUTION
[Publish Profile Copy Files To Relative Destination](https://stackoverflow.com/questions/45220194/publish-profile-copy-files-to-relative-destination)
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Copy-Assets {
#region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
  [Parameter(Mandatory = $True)]
  [string]$solutionDirectory

  ,[Parameter(Mandatory = $True)]
  [string]$copyTo
  )

#endregion FunctionParameters
#region FunctionBeginBlock
########################################
BEGIN {
  Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"
   $DebugPreference = 'Continue'

  # default values for settings
  $settings=@{
    InDir = '..\Data'
    InBusinessName1FilePattern = 'statistics'
    InBusinessName2FilePattern = 'unused'
    OutDir = '.'
    OutFNBusinessName1 = 'OutName1-'+(Get-Date).ToString('yyyyMMdd')+'.cfg'
    OutFNBusinessName2 = 'OutName2-'+(Get-Date).ToString('yyyyMMdd')+'.cfg'
  }

  # Things to be initialized after settings are processed
  if ($InDir) {$Settings.InDir = $InDir}
  if ($InFn1) {$Settings.InBusinessName1FilePattern = $InFn1}
  if ($InFn2) {$Settings.InBusinessName2FilePattern = $InFn2}
  if ($OutDir) {$Settings.OutDir = $OutDir}
  if ($OutFn1) {$Settings.OutFNBusinessName1 = $OutFn1}
  if ($OutFn2) {$Settings.OutFNBusinessName2 = $OutFn2}
  if ($OutFn3) {$Settings.OutFnOnDemandRules = $OutFn3}

  # Turn any input file name patterns that are of the form (..[,..]*) into arrays
  if ($settings.InBusinessName1FilePattern -match '^\(.*\)$') {$settings.InBusinessName1FilePattern = $settings.InBusinessName1FilePattern -replace ',','|'}
  if ($settings.InBusinessName2FilePattern -match '^\(.*\)$') {$settings.InBusinessName2FilePattern = $settings.InBusinessName2FilePattern -replace ',','|'}

  # In and out directory and file validations
  if (-not (test-path -path $settings.InDir -pathtype Container)) {throw "$settings.InDir is not a directory"}
  if (-not(ls $settings.InDir | ?{$_ -match $settings.InBusinessName1FilePattern})) {throw "there are no files matching {0} in directory {1}" -f $settings.InBusinessName1FilePattern,$settings.InDir}
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

  $OutFnName1 = join-path $settings.OutDir $settings.OutFnBusinessName1
  $OutFnName2 = join-path $settings.OutDir $settings.OutFnBusinessName2

  #Get the latest of each file that matches an alternate
  $InDataFile = (@(ls $settings.InDir | ?{$_ -match $settings.InBusinessName1FilePattern} | sort -Descending -Property 'LastWriteTime')[0]).Fullname

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
  Write-Verbose 'Directory copying from:' $directoryBase
  Write-Verbose 'Creating files found in include folder'
  # Path hack to copy files from directoryBase
  $directoryBaseHack = Join-Path $directoryBase '\*'
  Create-Files-Private -currentPath $directoryBaseHack -pathTo $path
  Write-Verbose 'Getting sub directories to copy from'
  $directories = Get-ChildItem -Path $directoryBase -Recurse | Where-Object { $_.PSIsContainer -eq $true }
  Write-Verbose 'Iterating through directories'
  foreach ($directory in $directories) {
    Write-Verbose 'Checking if directory'$directory.Name 'is part of absolute path.'
    if ($absolutePath -match $directory.Name) {
      # checking if directory already exists
      Write-Verbose 'Directory is part of absolute path, confirming if path exists'
      $alreadyExists = Test-Path $absolutePath
      if (!$alreadyExists) {
        Write-Verbose "Absolute path doesn't exist creating..."
        New-Item -ItemType Directory -Path $absolutePath -Force
        Write-Verbose 'All directories in path for Absolute Path created:'$absolutePath
      }
      Write-Verbose 'Directory for'$directory.Name 'already exists as it is part of the Absolute Path:' $absolutePath
    }
    else {
      Write-Verbose 'Joining path with absolute path'
      $path = Join-Path $absolutePath $directory.Name
      Write-Verbose 'Joined path:'$path

      Write-Verbose 'Does joined path exist:'$path
      $alreadyExists = Test-Path $path
      if (!$alreadyExists) {
        Write-Verbose "Joined path doesn't exist creating..."
        New-Item -ItemType Directory -Path $path -Force
        Write-Verbose 'Created new directory:' $path
      }
      Write-Verbose 'Directory for'$path 'already exists.'
    }
    Write-Verbose 'Creating files found in:' $directory
    Create-Files-Private -currentPath $directory -pathTo $path
  }

  Write-Verbose -Message "Ending $($MyInvocation.MyCommand)"
}
#endregion FunctionEndBlock
}
#endregion Copy-Assets
#############################################################################



function Create-Files-Private {
  Param ([string]$currentPath, [string]$pathTo)
  Write-Verbose 'Attempting to create files...'
  # Copy files from root include folder
  foreach ($file in (Get-ChildItem -Path $currentPath | Where-Object { $_.PSIsContainer -eq $false })) {
    Write-Verbose 'Attempting to copy file:'$file 'to'$path
    New-Item -ItemType File -Path $pathTo -Name $file.Name -Force
  }
}


