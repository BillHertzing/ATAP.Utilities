#############################################################################
#region Invoke-MSBuildWithLists
<#
.SYNOPSIS
ToDo: Repeatdly invoke msbuild, substituting propertis with lists of arguments
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function

[Naming PowerShell custom objects and setting their default display properties](https://rakhesh.com/powershell/naming-powershell-custom-objects-and-setting-their-default-display-properties/) - rakhesh sasidharan
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

.EXAMPLE
ToDo: write Help For example 2 of using this function
.EXAMPLE
ToDo: write Help For example 3 of using this function
.LINK
https://rakhesh.com/powershell/naming-powershell-custom-objects-and-setting-their-default-display-properties/
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Invoke-MSBuildWithLists {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)][string] $path
    , [parameter(Mandatory = $false)][string[]] $outputPath
    , [parameter(Mandatory = $false)][string[]] $baseIntermediateOutputPath
    , [parameter(Mandatory = $false)][string[]] $runtimeTargetList
    , [parameter(Mandatory = $false)][string[]] $targetFrameworkList
    , [parameter(Mandatory = $false)][string[]] $configurationlist

  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"
    # default values for settings
    $settings = @{
      Path                       = './'
      OutputPath                 = './bin'
      BaseIntermediateOutputPath = './obj'
      RuntimeTargetList          = $('win-x64', 'win-x86', 'linux-x64', 'linux-arm')
      TargetFrameworkList        = $('core', 'net46', 'net47')
      ConfigurationList          = $('Debug', 'Release', 'ReleaseWithTrace')
    }

    # Things to be initialized after settings are processed
    if ($path) { $Settings.Path = $path }
    if ($outputPath) { $Settings.OutputPath = $outputPath }
    if ($baseIntermediateOutputPath) { $Settings.BaseIntermediateOutputPath = $baseIntermediateOutputPath }
    if ($RuntimeTargetList) { $Settings.RuntimeTargetList = $RuntimeTargetList }
    if ($targetFrameworkList) { $Settings.TargetFrameworkList = $targetFrameworkList }
    if ($configurationList) { $Settings.ConfigurationList = $configurationList }

    # Turn any input file name patterns that are of the form (..[,..]*) into arrays
    #if ($settings.InBusinessName1FilePattern -match '^\(.*\)$') {$settings.InBusinessName1FilePattern = $settings.InBusinessName1FilePattern -replace ',','|'}
    #if ($settings.InBusinessName2FilePattern -match '^\(.*\)$') {$settings.InBusinessName2FilePattern = $settings.InBusinessName2FilePattern -replace ',','|'}

    # In and out directory and file validations
    if (-not (Test-Path -Path $settings.Path)) { throw "$settings.Path was not found" }

    # MSBuild will create the two output directories if they don't exist

    #Get the latest of each file that matches an alternate
    # $InDataFile = (@(ls $settings.InDir | ?{$_ -match $settings.InBusinessName1FilePattern} | sort -Descending -Property 'LastWriteTime')[0]).Fullname

    # Absolute path to copy files to and create folders in
    # $absolutePath = @($copyTo + '/App_Config/Include')
    # # Set paths we will be copy files from
    # $featureDirectory = Join-Path $solutionDirectory '/Feature/*/App_Config/Include'
    # $foundationDirectory = Join-Path $solutionDirectory '/Foundation/*/App_Config/Include'


  }
  #endregion FunctionBeginBlock
  #region FunctionProcessBlock
  ########################################
  PROCESS {
    Write-Verbose -Message "processing $($MyInvocation.MyCommand)"

    # Crate an object to hold the rsults for each pipeline input
    $results = New-Object PSObject -Property @{
      Errors   = @()
      ExitCode = [int]0
    }
    # define 'exitcode' to ge the default property of the object
    $defaultProperties = @('ExitCode')
    $results | Add-Member MemberSet PSStandardMembers (
      [System.Management.Automation.PSMemberInfo[]]@(
        (New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’, [string[]]$defaultProperties))
      )
    )
    foreach ($localRuntimeTarget in $Settings.RuntimeTargetList) {
      foreach ($localConfiguration in $Settings.ConfigurationList) {
        foreach ($localTargetFramework in $Settings.TargetFrameworkList) {
          $cmdAsString = 'dotnet build {0} -p:OutputPath={1} -p:BaseIntermediateOutputPath={2} -p:RuntimeTarget={3} -p:Configuration={4} -p:TargetFramework={5}' -f $Settings.Path, $Settings.OutputPath, $Settings.BaseIntermediateOutputPath, $localRuntimeTarget, $localConfiguration, $localTargetFramework
          if ($PSCmdlet.ShouldProcess('', "$cmdAsString")) {
            $localExitCode = Invoke-Expression $cmdAsString
            if ($localExitCode -ne 0) {
              # ToDo: assemble failure details
              # The usual PS way fails, claiming that $results.exitcode is not an int, claiminig instead that it is a [System.Object[]]
             # [int]$resultsExitcode = ($results).exitcode
              $results.ExitCode = $results.Exitcode + $localExitCode
            }
          }
          # Pack into NuGet Package
          Write-Verbose 'Pack '
        }
      }
    }
  }

  # return $results for each pipeline input
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    Write-Verbose -Message "Ending $($MyInvocation.MyCommand)"
  }
  #endregion FunctionEndBlock
}
#endregion Invoke-MSBuildWithLists
#############################################################################
