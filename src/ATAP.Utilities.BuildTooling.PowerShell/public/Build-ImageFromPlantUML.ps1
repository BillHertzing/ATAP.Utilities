<#
.SYNOPSIS
Walk a directory and generate PlantUML images for supported files.
.DESCRIPTION
Given an input directory, this cmdlet invokes the PlantUML jar on files with extensions txt, pu, puml, md, etc.,
mirroring the directory structure under the specified output directory.
.EXAMPLE
Build-ImageFromPlantUML -InDir .\docs -OutBaseDir .\_site
.INPUTS
String (path to input directory)
.OUTPUTS
None
.NOTES
Requires Java and the PlantUML jar. Supports ShouldProcess for safe operations.
#>

function Build-ImageFromPlantUML {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
  [Alias('New-PlantUmlImages')]
  [OutputType([void])]
  param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InDir,
    [Parameter(Mandatory = $false)]
    [string]$InBaseDir,
    [Parameter(Mandatory = $false)]
    [string]$ExcludedSubDirPattern,
    [Parameter(Mandatory = $false)]
    [string]$OutBaseDir,
    [Parameter(Mandatory = $false)]
    [string]$OutRelativeDir,
    [Parameter(Mandatory = $false)]
    [string]$PlantUMLJarPath,
    [Parameter(Mandatory = $false)]
    [ValidateSet('SVG', 'PNG')][string]$OutType
  )

  BEGIN {
    Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Entering Function Build-ImageFromPlantUML"

    $Settings = [ordered] @{
      InDir                 = ''
      InBaseDir             = Get-Location
      ExcludedSubDirPattern = ''
      OutBaseDir            = Get-Location
      OutRelativeDir        = '_site/Assets/images/$'
      OutType               = 'PNG'
      PlantUMLJarPath       = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
      FileSuffixToScan      = @('apt', 'c', 'cpp', 'cs', 'h', 'hh', 'htm', 'html', 'hpp', 'java', 'md', 'txt', 'tex', 'pu', 'puml')
    }

    # Things to be initialized after settings are processed
    if ($InDir) { $Settings.InDir = $InDir }
    if ($InBaseDir) { $Settings.InBaseDir = $InBaseDir }
    if ($ExcludedSubDirPattern) { $Settings.ExcludedSubDirPattern = $ExcludedSubDirPattern }
    if ($OutBaseDir) { $Settings.OutBaseDir = $OutBaseDir }
    if ($OutRelativeDir) { $Settings.OutRelativeDir = $OutRelativeDir }
    if ($OutType) { $Settings.OutType = $OutType }
    if ($PlantUMLJarPath) { $Settings.PlantUMLJarPath = $PlantUMLJarPath }
    if ($Settings.OutType -match '^SVG$') { $Settings.OutRelativeDir = $Settings.OutRelativeDir } # ToDo: should OutType re-write the outdir final path element?

    $SettingsAsString = $Settings.Keys | ForEach-Object { $key = $_; "$key : $($Settings[$key])" } # ToDo: study if write-hashindented is better
    Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Verbose -Message "Initial Settings: $SettingsAsString"

    $OutRelativeDirForGenerated = [System.IO.Path]::GetRelativePath($Settings.OutBaseDir, $Settings.OutRelativeDir)
    Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Verbose -Message "OutRelativeDirForGenerated: $OutRelativeDirForGenerated"

    # Plantuml is funny, it needs an absolute path for the -o parameter to create a tree, else all files go into the output subdirectory flat
    # Attribution: https://forum.plantuml.net/9942/keep-the-original-directory-architecture-in-output
    # The link above is the first and so far only  reference I found to /$, the magic sauce that makes this work
    $OutputDirectoryAbsolute = (Join-Path $Settings.OutBaseDir $Settings.OutRelativeDir) + '/$'
    Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "OutputDirectoryAbsolute: $OutputDirectoryAbsolute"

  }
  PROCESS {
    try {
      if ($InDir -notmatch $Settings.ExcludedSubDirPattern) {
        # plantuml jar wants a trailing slash in the InDir
        $InDir + '\'
        $InRelativeDir = [System.IO.Path]::GetRelativePath($Settings.InBaseDir, $InDir)
        # ToDo: better string representation for Linux (don't use double-quotes around paths, get the slashes correct)
        $baseCmdAsString = $cmdAsString = 'java -jar ' + '"' + $Settings.PlantUMLJarPath + '"' + ' -o ' + '"' + $OutputDirectoryAbsolute + '" '
        # This command will search for @startXYZ and @endXYZ into .txt, .tex, .java, .htm, .html, .c, .h, .cpp, .apt, .pu, .puml, .hpp or .hh files of the $InRelativeDir directory
        # Run the command only if any files of the default suffix exist in InRelativeDir
        $cmdAsString = $baseCmdAsString + '"' + $InRelativeDir + '"'
        if ($PSCmdlet.ShouldProcess("$InRelativeDir", $cmdAsString)) {
          Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Calling: $cmdAsString" -Tag 'InvokeExpressionCall'
          java -jar $($Settings.PlantUMLJarPath) -o $OutputDirectoryAbsolute $InRelativeDir
          Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Successfully returned from: $cmdAsString" -Tag 'InvokeExpressionCall'
        }
        # ToDo: grow this to accept a list of additional file suffixes
        $InDirAdditionalPattern = $InRelativeDir + '**\*.md'
        # This command will search for @startXYZ and @endXYZ into .md files of the $InRelativeDir (as relative to InBaseDir) directory and subdirectories
        #$cmdAsString = $baseCmdAsString + '"' + $InDirAdditionalPattern + '"'
        if ($PSCmdlet.ShouldProcess("$InDirAdditionalPattern", $cmdAsString)) {
          Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Calling: $cmdAsString" -Tag 'InvokeExpressionCall'
          java -jar $($Settings.PlantUMLJarPath) -o $OutputDirectoryAbsolute $InDirAdditionalPattern > $null
          Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Successfully returned from: $cmdAsString" -Tag 'InvokeExpressionCall'
        }
      }
    }
    catch {
      $err = $_
      $errorMessage = "Exception processing InDir '$InDir' : $($err.Exception.Message)"
      Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Error -Message $errorMessage
      if ($err.Exception.StackTrace) {
        $errorMessage = "StackTrace: $($err.Exception.StackTrace)"
        Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message $errorMessage
      }
      throw $err
    }
    finally {
      Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Leaving Function Build-ImageFromPlantUML"
    }
  }
  END {
    Write-PSFMessage -FunctionName 'Build-ImageFromPlantUML' -ModuleName 'ATAP.Utilities.BuildTooling.PowerShell' -Level Debug -Message "Leaving Function Build-ImageFromPlantUML"
  }
}
