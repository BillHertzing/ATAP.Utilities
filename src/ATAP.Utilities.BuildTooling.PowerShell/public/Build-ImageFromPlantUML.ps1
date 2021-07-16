
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

    $Settings = @{
      InDir            = ''
      InBaseDir        = Get-Location
      OutBaseDir       = Get-Location
      OutRelativeDir   = '_site/Assets/images'
      OutType          = 'PNG'
      PlantUMLJarPath  = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
      FileSuffixToScan = @('txt', 'tex', 'java', 'htm', 'html', 'c', 'h', 'cpp', 'apt', 'pu', 'puml', 'hpp' , 'hh')
    }

    # Things to be initialized after settings are processed
    if ($InDir) { $Settings.InDir = $InDir }
    if ($InBaseDir) { $Settings.InBaseDir = $InBaseDir }
    if ($OutBaseDir) { $Settings.OutBaseDir = $OutBaseDir }
    if ($OutRelativeDir) { $Settings.OutRelativeDir = $OutRelativeDir }
    if ($OutType) { $Settings.OutType = $OutType }
    if ($PlantUMLJarPath) { $Settings.PlantUMLJarPath = $PlantUMLJarPath }
    if ($Settings.OutType -match '^SVG$') { $Settings.OutRelativeDir = $Settings.OutRelativeDir } # ToDo: should OutType re-write the outdir final path element?

    $SettingsAsString = $settings.Keys | ForEach-Object { $key = $_; $key.ToString() + ' : ' + $Settings[$key].ToString() }
    Write-Verbose -Message "BEGIN: Initial Settings: $SettingsAsString"

    $OutRelativeDirForGenerated = [System.IO.Path]::GetRelativePath($Settings.OutBaseDir, $Settings.OutRelativeDir)
    Write-Verbose -Message "BEGIN: OutRelativeDirForGenerated: $OutRelativeDirForGenerated"

  }
  #endregion FunctionBeginBlock
  #region FunctionProcessBlock
  ########################################
  PROCESS {
    # Move the pipeline variable into the $settings hash
    $Settings.InDir = $InDir
    $InRelativeDir = [System.IO.Path]::GetRelativePath($Settings.InBaseDir, $InDir)
    # $absoluteOutPath = Join-path $Settings.InDir $Settings.OutRelativeDir
    Write-Verbose -Message "PROCESS: InRelativeDir : $InRelativeDir "
    # This command will search for @startXYZ and @endXYZ into .txt, .tex, .java, .htm, .html, .c, .h, .cpp, .apt, .pu, .puml, .hpp or .hh files of the $Settings.InDir directory
    # Run the command only if any files of the default suffix exist in InRelativeDir
    # ToDo: better string represntation for Linux (don't use parenthesis)
    $cmdAsString = 'java -jar ' + "$($Settings.PlantUMLJarPath)" + ' -o "' + $OutRelativeDirForGenerated + '" "' + $InRelativeDir + '"'
    if ($PSCmdlet.ShouldProcess("$($Settings.InDir)", $cmdAsString)) {
      java -jar $($Settings.PlantUMLJarPath) -o $absoluteOutPath $($Settings.InDir)
    }
    # This command will search for @startXYZ and @endXYZ into .md files of the $Settings.InDir directory
    $cmdAsString = 'java -jar ' + $($Settings.PlantUMLJarPath) + ' -o ' + $OutRelativeDirForGenerated + ' "' + $InRelativeDir + '/**/*.md" '
    if ($PSCmdlet.ShouldProcess("$($Settings.InDir)", $cmdAsString)) {
      java -jar $($Settings.PlantUMLJarPath) -o $absoluteOutPath "$($Settings.InDir)/**/*.md"
    }

  }
  #endregion FunctionProcessBlock
  #region FunctionEndBlock
  ########################################
  END {
  }
}


