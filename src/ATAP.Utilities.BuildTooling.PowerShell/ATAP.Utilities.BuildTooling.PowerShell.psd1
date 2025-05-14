#
# Module manifest for module 'ATAP.Utilities.BuildTooling.Powershell'

@{

  # Script module or binary module file associated with this manifest.
  RootModule           = 'ATAP.Utilities.BuildTooling.Powershell.psm1'

  # Version number of this module.
  ModuleVersion        = '0.0.5'

  # Supported PSEditions
  CompatiblePSEditions = 'Desktop', 'Core'

  # ID used to uniquely identify this module
  GUID                 = 'DBD8663F-C30C-4702-B97A-5365529B4D15'

  # Author of this module
  Author               = 'Bill Hertzing for ATAPUtilities.org'

  # Company or vendor of this module
  CompanyName          = 'ATAPUtilities.org'

  # Copyright statement for this module
  Copyright            = '(c) 2018 - 2025  Bill Hertzing . All rights reserved. All code is under the MIT license'

  # Description of the functionality provided by this module
  Description          = 'Powershell scripts used for building the ATAPUtilities'

  # Minimum version of the PowerShell engine required by this module
  PowerShellVersion    = '5.1'

  # Name of the PowerShell host required by this module
  # PowerShellHostName = ''

  # Minimum version of the PowerShell host required by this module
  # PowerShellHostVersion = ''

  # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # DotNetFrameworkVersion = ''

  # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # CLRVersion = ''

  # Processor architecture (None, X86, Amd64) required by this module
  # ProcessorArchitecture = ''

  # Modules that must be imported into the global environment prior to importing this module
  RequiredModules      = @(
    @{ ModuleName = 'PSFramework'; ModuleVersion = '1.10.0' },
    @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.0' }
  )

  # Assemblies that must be loaded prior to importing this module
  RequiredAssemblies   = @()

  # Script files (.ps1) that are run in the caller's environment prior to importing this module.
  # ScriptsToProcess = @()

  # Type files (.ps1xml) to be loaded when importing this module
  # TypesToProcess = @()

  # Format files (.ps1xml) to be loaded when importing this module
  # FormatsToProcess = @()

  # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
  # NestedModules = @()

  # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
  FunctionsToExport    = @('Build-ImageFromPlantUML', 'Clear-NuGetCaches', 'Copy-Assets', 'Get-BrokenGitSubDirs', 'Get-CoreInfo', 'Get-JenkinsEnvSettings', 'Get-ModuleAsSymbolicLink', 'Get-NumberOfFailingTestsFromTRX', 'Get-SLNParts', 'Get-ProjectsFromSLN', 'Invoke-MSBuildWithLists', 'Invoke-Webserver', 'New-AssemblyInfoFiles', 'New-DocFilesIfNotPresent', 'New-DocFolderIfNotPresent', 'Remove-ObjAndBinSubdirs', 'Remove-VSComponentCache', 'Start-DebugPowerShell', 'Update-BlocksInCsproj')

  # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
  CmdletsToExport      = '*'

  # Variables to export from this module
  VariablesToExport    = '*'

  # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
  AliasesToExport      = @()

  # DSC resources to export from this module
  # DscResourcesToExport = @()

  # List of all modules packaged with this module
  ModuleList           = @()

  # List of all files packaged with this module
  # FileList = @()

  # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
  PrivateData          = @{

    PSData = @{

      # Tags applied to this module. These help with module discovery in online galleries.
      # Tags = @()

      # A URL to the license for this module.
      # LicenseUri = ''

      # A URL to the main website for this project.
      # ProjectUri = ''

      # A URL to an icon representing this module.
      # IconUri = ''

      # ReleaseNotes of this module
      # ReleaseNotes = ''

      # Prerelease string of this module
      Prerelease = '1'

      # Flag to indicate whether the module requires explicit user acceptance for install/update/save
      # RequireLicenseAcceptance = $false

      # External dependent modules of this module
      # ExternalModuleDependencies = @()

    } # End of PSData hashtable

  } # End of PrivateData hashtable

  # HelpInfo URI of this module
  # HelpInfoURI = ''

  # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
  # DefaultCommandPrefix = ''

}

