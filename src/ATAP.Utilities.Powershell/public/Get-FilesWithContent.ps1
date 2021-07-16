#############################################################################
#region Get-FilesWithContent
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER Path
  Specifies the path where searching should start. May be a string or an array in the form (p1[,p2][,p3]...)
.PARAMETER FileNamePattern
  Specifies the regex pattern to match filenames against. May be a string or an array in the form (r1[,r2][,r3]...)

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
Function Get-FilesWithContent {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: Paramter set to suport LiteralPath
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] $Path
    , [alias('Pattern')]
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] $FileNamePattern
    , [alias('Include')]
    # ToDo: Better job of accepting arrays as an argument
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)][String] $IncludeFilterPattern
    , [alias('Content')]
    [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)] $FileContentPattern
    # ToDo: Add a Paramter set so that Depth is only allowed if -Recurse is specified
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)][switch] $Recurse
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)][int][ValidateRange(1, [int]::MaxValue)] $Depth
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)][switch] $Force
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    $DebugPreference = 'Continue'

    # default values for settings
    $settings = @{
      Path               = './'
      FileNamePattern    = ''
      IncludeFilterPattern    = ''
      FileContentPattern = '.*'
      Recurse            = ''
      Depth            = 0
      Force              = ''
    }

    # Things to be initialized after settings are processed
    if ($Path) { $Settings.Path = $Path }
    if ($FileNamePattern) { $Settings.FileNamePattern = $FileNamePattern }
    if ($IncludeFilterPattern) { $Settings.IncludeFilterPattern = $IncludeFilterPattern }
    if ($FileContentPattern) { $Settings.FileContentPattern = $FileContentPattern }
    if ($Recurse) { $Settings.Recurse = $Recurse }
    if ($Depth) { $Settings.Depth = $Depth }
    if ($Force) { $Settings.Force = $Force }

    # Turn any input file name patterns that are of the form (..[,..]*) into arrays
    if ($settings.FileNamePattern -match '^\(.*\)$') { $settings.FileNamePattern = $settings.FileNamePattern -replace ',', '|' }

    # In and out directory and file validations
    if (-not (Test-Path -Path $settings.Path -PathType Container)) { throw "$settings.Path is not a directory" }
    # This line sould not be run if the path can get big
    # if (-not(Get-ChildItem $($settings.Recurse ? '-R' : '') $($settings.Force ? '-Force' : '') $settings.Path | Where-Object{$_ -match $settings.FileNamePattern})) {throw "there are no files matching {0} in directory {1} {2}" -f $settings.FileNamePattern, $settings.Path, ($settings.Recurse ? '-R' : '')}

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

    $acc = @{}
    $gciCommand = 'Get-ChildItem ' `
     + "-Path " + $settings.Path + ' ' `
     + $(if($settings.Recurse) {'-Recurse '}) `
     + $(if($settings.Depth -gt 0) {"-Depth " + $settings.Depth + ' '}) `
     + $(if($settings.Force ) {'-force '}) `
     + $(if(-not [string]::IsNullOrWhiteSpace($settings.IncludeFilterPattern)) {"-Include " + $settings.IncludeFilterPattern + ' '})

    $time = Measure-Command {
      Invoke-Expression $gciCommand |
      Where-Object { ($_.fullname -notmatch '\\WPK\\') -AND ($_.fullname -match $Settings.FileNamePattern) } |
      ForEach-Object { $fullname= $_.fullname; Get-Content $fullname | ForEach-Object { $line = $_;
          if ($line -match $Settings.FileContentPattern) {
            $entry = [PSCustomObject]@{
              LineNumber = $line.ReadCount
              Line       = $line.ToString()
            }
            if (! $acc.containskey($fullname)) { $acc[$fullname] = @($entry) } else { $acc[$fullname] += $entry }
          }
        }
      }
    }

    $OutObj = [PSCustomObject]@{
      Results = $acc
      Time    = $time
      gciCommand = $gciCommand
    }
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
    return $OutObj
  }
  #endregion FunctionEndBlock
}
#endregion Get-FilesWithContent
#############################################################################


