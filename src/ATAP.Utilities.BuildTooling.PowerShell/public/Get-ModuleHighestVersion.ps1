#Requires -Modules PowerShellGet
#Requires -Version 5.0
#region Get-ModuleHighestVersion
<#
.SYNOPSIS
ToDo: write Help SYNOPSIS For this function
.DESCRIPTION
ToDo: write Help DESCRIPTION For this function
.PARAMETER  ModuleName
  Specifies the path to the Powershell Manifest file (.psd1)
.PARAMETER ProductionOnly
  Specifies the path to the directory where the .nuspec file will be written

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
.LINK
ToDo
.LINK
ToDo: insert link to internet articles that contributed ideas / code used in this function e.g. http://www.somewhere.com/attribution.html
.SCM
ToDo: insert SCM keywords markers that are automatically inserted <Configuration Management Keywords>
#>
Function Get-ModuleHighestVersion {
  [CmdletBinding(PositionalBinding = $false)]
  Param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]  $moduleName
    , [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    # ToDo: Make this an aarray of instances of a class with three fields instead of a string array
    [string[]] $Sources
    , [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [switch] $PublicOnly
  )
  #region BeginBlock
  BEGIN {
    # $DebugPreference = 'SilentlyContinue' # Continue SilentlyContinue
    # $VerbosePreference = 'SilentlyContinue' # Continue SilentlyContinue
    Write-PSFMessage -Level Debug -Message 'Entering Function %FunctionName% in module %ModuleName%' -Tag 'Trace'
  }
  #endregion BeginBlock
  #region ProcessBlock
  PROCESS {}
  #endregion ProcessBlock
  #region EndBlock
  END {
    Write-PSFMessage -Level Debug -Message "Workspace = $([System.Environment]::GetEnvironmentVariable('Workspace'))" -Tag 'Jenkins', 'Publish'

    $highestSemanticVersion = $lowestSemanticVersion
    $REPattern = '(?<ProviderName>NuGet|PowershellGet|Chocolatey)(?<ProviderLifecycle>Filesystem|QualityAssuranceWebServer|ProductionWebServer)(?<PackageLifecycle>Development|QualityAssurance|Production)'
    for ($i = 0; $i -lt $sources.count; $i++) {
      $source = $sources[$i]
      # Split the source into its three parts
      if ($source -imatch $config[$REPattern]) {
        $ProviderName = $matches['ProviderName'];
        $ProviderLifecycle = $matches['ProviderLifecycle'];
        $PackageLifecycle = $matches['PackageLifecycle'];
      }
      else {
        $message = "source = $source; it does not imatch $REPattern"
        Write-PSFMessage -Level Error -Message $message -Tag 'Jenkins', 'Publish'
        Throw $message

      }
    }
    # Does the ModuleName exist in any repository
    $allPackageVersions = Find-Package -Name $ModuleName -AllowPrereleaseVersions
    $highestVersionIndex = $null
    for ($i = 0; $i -lt $allPackageVersions.count; $i++) {
      if ($($allPackageVersions[$i]).Version -gt $highestSemanticVersion) {
        $highestVersionIndex = $i
        $highestSemanticVersion = $($allPackageVersions[$i]).Version
      }
    }
    # get the manifest for the highest version found
  }
  #endregion EndBlock
}
#endregion Get-ModuleHighestVersion
