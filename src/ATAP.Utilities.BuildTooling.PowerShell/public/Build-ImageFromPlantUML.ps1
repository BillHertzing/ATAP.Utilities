
<#
Given an input directory, walk it and run the java Plantuml jar file against every default file extension and .md file, placing the results in a tree rooted at output directory
This expects to be run at a root of a repo that has a child named Documentation

#>

Function Build-ImageFromPlantUML {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: two or more parameter sets, to deal with both Path and LiteralPath
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)][string] $InDir
    , [parameter(Mandatory = $false)][string] $InBaseDir
    , [parameter(Mandatory = $false)][string] $ExcludedSubDirPattern
    , [parameter(Mandatory = $false)][string] $OutBaseDir
    , [parameter(Mandatory = $false)][string] $OutRelativeDir
    , [parameter(Mandatory = $false)][string] $PlantUMLJarPath
    , [parameter(Mandatory = $false)] [ValidateSet('SVG', 'PNG')][string] $OutType
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

    $Settings = [ordered] @{
      InDir                 = ''
      InBaseDir             = Get-Location
      ExcludedSubDirPattern = ''
      OutBaseDir            = Get-Location
      OutRelativeDir        = '_site/Assets/images/$'
      OutType               = 'PNG'
      PlantUMLJarPath       = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
      FileSuffixToScan      = @('txt', 'tex', 'java', 'htm', 'html', 'c', 'h', 'cpp', 'apt', 'pu', 'puml', 'hpp' , 'hh')
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

    $SettingsAsString = $settings.Keys | ForEach-Object { $key = $_; $key.ToString() + ' : ' + $Settings[$key].ToString() }
    Write-Verbose -Message "BEGIN: Initial Settings: $SettingsAsString"

    $OutRelativeDirForGenerated = [System.IO.Path]::GetRelativePath($Settings.OutBaseDir, $Settings.OutRelativeDir)
    Write-Verbose -Message "BEGIN: OutRelativeDirForGenerated: $OutRelativeDirForGenerated"

    # Plantuml is funny, it needs an absolute path for the -o parameter to create a tree, else all files go into the output subdirectory flat
    # Attribution: https://forum.plantuml.net/9942/keep-the-original-directory-architecture-in-output
    # The link above is the first and so far only  reference I found to /$, the magic sauce that makes this work
    $OutputDirectoryAbsolute = (Join-Path $Settings.OutBaseDir $Settings.OutRelativeDir) + '/$'
    Write-Debug -Message "BEGIN: OutputDirectoryAbsolute: $OutputDirectoryAbsolute"

  }
  #endregion FunctionBeginBlock
  #region FunctionProcessBlock
  ########################################
  PROCESS {
    if ($InDir -notmatch $settings.ExcludedSubDirPattern) {
      # plantuml jar wants a trailing slash in the InDir
      $InDir + '\'
      $InRelativeDir = [System.IO.Path]::GetRelativePath($Settings.InBaseDir, $InDir)
      # ToDo: better string representation for Linux (don't use double-quotes around paths, get the slashes correct)
      $baseComdAsString = $cmdAsString = 'java -jar ' + '"' + $Settings.PlantUMLJarPath + '"' + ' -o ' + '"' + $OutputDirectoryAbsolute + '" '
      # This command will search for @startXYZ and @endXYZ into .txt, .tex, .java, .htm, .html, .c, .h, .cpp, .apt, .pu, .puml, .hpp or .hh files of the $InRelativeDir directory
      # Run the command only if any files of the default suffix exist in InRelativeDir
      $cmdAsString = $baseComdAsString + '"' + $InRelativeDir + '"'
      if ($PSCmdlet.ShouldProcess("$InRelativeDir", $cmdAsString)) {
        #$InRelativeDir
        java -jar $($Settings.PlantUMLJarPath) -o $OutputDirectoryAbsolute $InRelativeDir
      }
      # ToDo: grow this to accept a list of additional file suffixs
      $InDirAdditionalPattern = $InRelativeDir + '**\*.md'
      # This command will search for @startXYZ and @endXYZ into .md files of the $InRelativeDir (as relative to InBaseDir) directory and subdirectories
      $cmdAsString = $baseComdAsString + '"' + $InDirAdditionalPattern + '"'
      if ($PSCmdlet.ShouldProcess("$InDirAdditionalPattern", $cmdAsString)) {
        # $($InRelativeDirMDPattern)
        java -jar $($Settings.PlantUMLJarPath) -o $OutputDirectoryAbsolute $InDirAdditionalPattern > null
      }
    }
  }
  #endregion FunctionProcessBlock
  #region FunctionEndBlock
  ########################################
  END {
  }
}


