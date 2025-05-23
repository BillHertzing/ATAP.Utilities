#############################################################################
#region Confirm-Tools
<#
.SYNOPSIS
Confirm that all the 3rd party tools and scripts needed to build, analyze, test, package and deploy both c# and powershell code are present, configured, and accessable,
.DESCRIPTION
This function looks for the presence of tools needed by the ATAP.Utilities to
  - compile and interpret c# and Powershell code (text files to executable production code)
  - automate testing of the powershell packages and c#-sourced libraries
  - create documentation from code
  - generate class diagrams from code
  - integrate the generated diagrams with the generated documentation,
  - suports draw.io engineering drawings
  - generte a static documentation site from code, conceptual documentation, and diagram files
  - provide Source Code Management (SCM)
  - create and maintain SQL Server databases and Neo4j databases
  - provide for database SCM (Flyway from Redhat)
  - run the CI/CD pipeline
  - provide message queing and inter-computer messaging
  - create deployment package for .Net libraries and applications
  - deploy packages to internal and external location, to three public location (PSGallery, Nuget, and Chocolatey)

.PARAMETER Name
ToDo: write Help For the parameter X
.PARAMETER Extension
ToDo: write Help For the parameter X
.INPUTS
Environment variables drive the action that this Cmdlet takes.
Machine and container nodes are grouped and assigned capabilities (roles).
Roles imply a promise that certain tools will be available in the environments that certain actions can occur.

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
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'NoParameters')]
  param (
    [parameter(ParameterSetName = 'PackageRepositoriesParameters')]
    [array] $PackageSourceNames
    , [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True, Mandatory = $False)]
    [string] $Encoding # Often found in the $PSDefaultParameterValues preference variable
  )

  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    # Set these as needed for debugging the script
    # Don't Print any debug messages to the console
    $DebugPreference = 'SilentlyContinue' # SilentlyContinue Continue
    # Don't Print any verbose messages to the console
    $VerbosePreference = 'Continue' # SilentlyContinue Continue
    Write-PSFMessage -Level Debug -Message "Starting Confirm-Tools.ps1; Encoding = $Encoding"

    # # Output tests
    # if (-not (Test-Path -Path $settings.OutDir -PathType Container)) {
    #   throw "$settings.OutDir is not a directory"
    # }
    # # Validate that the $Settings.OutDir is writable
    # $testOutFn = $settings.OutDir + 'test.txt'
    # try { New-Item $testOutFn -Force -type file >$null
    # }
    # catch { # if an exception occurs
    #   # handle the exception
    #   $where = $PSItem.InvocationInfo.PositionMessage
    #   $ErrorMessage = $_.Exception.Message
    #   $FailedItem = $_.Exception.ItemName
    #   #Log('Error', "new-item $testOutFn -force -type file failed with $FailedItem : $ErrorMessage at $where.");
    #   Throw "new-item $testOutFn -force -type file failed with $FailedItem : $ErrorMessage at $where."
    # }
    # # Remove the test file
    # Remove-Item $testOutFn -ErrorAction Stop

    # $datestr = Get-Date -AsUTC -Format 'yyyy/MM/dd:HH.mm'

    # # Read in the contents of the last $OutPath file as a hash
    # $dateKeyedHash = if (Test-Path -Path $OutPath) { gc $OutPath | ConvertFrom-Json -asHash } else { @{}
    # }
    Write-Verbose 'Validating tools and configurations are present'
  }
  #endregion FunctionBeginBlock

  #region FunctionProcessBlock
  ########################################
  PROCESS {
    # ToDo: Replace with enumeration
    ('NuGet', 'PowershellGet', 'ChocolateyGet') | ForEach-Object { $ProviderName = $_
      # Confirm-RepositoryPackageProvider will throw if it cannot be installed
      Confirm-RepositoryPackageProvider -ProviderName $ProviderName
      ('Filesystem', 'QualityAssuranceWebServer', 'ProductionWebServer') | ForEach-Object { $ProviderLifecycle = $_
        ('QualityAssurance', 'Production') | ForEach-Object { $PackageLifecycle = $_
          # validate each $ProviderName / ProviderLifecycle / PackageLifecycle cross exists. (installing should be done during container setup)
          $RepositoryPackageSourceName = $ProviderName + $ProviderLifecycle + $PackageLifecycle + 'Package'
          # Confirm-RepositoryPackageProvider will throw if the RepositoryPackageSourceName cannot be registered
          Confirm-RepositoryPackageSource -RepositoryPackageSourceName $RepositoryPackageSourceName
        }
      }
    }
  }
  #endregion FunctionProcessBlock

  #region FunctionEndBlock
  ########################################
  END {
    # $str = nuget locals all -list
    # $dateKeyedHash[$datestr ] = $str
    # $dateKeyedHash | ConvertTo-Json | Set-Content -Path $OutPath
  }
  #endregion FunctionEndBlock
}
#endregion Confirm-Tools
#############################################################################

