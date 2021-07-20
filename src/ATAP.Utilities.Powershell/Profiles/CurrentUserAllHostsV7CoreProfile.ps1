<#
.SYNOPSIS 
PowerShell profile template for individual developers
.DESCRIPTION
TBD

.INPUTS
None
.OUTPUTS
None
.EXAMPLE

.LINK
http://www.somewhere.com/attribution.html
.LINK
<Another link>
.ATTRIBUTION
<Where the ideas came from>
.SCM
<Configuration Management Keywords>
#>

########################################################
# Individual PowerShell Profile
########################################################

$settings={
  dummy:'dummy'
}
#Get-Settings $SettingsFile

# Setup Logging after settings are processed
#$LogFn =$settings.LogFnPath + $settings.LogFnPattern;
#Init-Log4Net $LogFn

# Things to be initialized after settings are processed

########################################################
# Console Settings
##############################
# Don't Print any debug messages to the console
$DebugPreference = "SilentlyContinue"
# Don't Print any verbose messages to the console
$VerbosePreference = "Continue" #"SilentlyContinue"
# Number of commands to keep in the commandHistory
$global:MaxHistoryCount = 1000
# Size of the console's user interface
Function ConsoleSettings {
  $console = $host.ui.Rawui
  ($console.BufferSize).width = 200
  ($console.BufferSize).height = 3000
  ($console.windowSize).width = 200
  ($console.windowSize).height = 100
}
if ($host.ui.Rawui.WindowTitle -notmatch 'ISE') {ConsoleSettings}

# Structure of package drop location; File Server Shares (fss) and Web Server URLs
$drops = @{fssdev='\\fs\pkgsDev';fssqa='\\fs\pkgsqa';fssprd='\\fs\pkgs';wsudev='http://ws/ngf/dev';wsuqa='http://ws/ngf/qa';wsuprd='http://ws/ngf'} 

# set the Cloud Location variables
Function Set-CloudDirectoryLocations {
  switch -regex ($env:computername) {
    'ncat016' {
      $global:DropBoxBaseDir = 'C:\Dropbox\'
      $global:OneDriveBaseDir = 'C:\OneDrive\'
      #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      #$nPSModulePath = $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      break
    }
    'ncat040' {
      $global:DropBoxBaseDir = 'C:\Dropbox\'
      $global:OneDriveBaseDir = 'C:\OneDrive\'
      #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      #$nPSModulePath = $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      break
    }
    'ncat-ltjo' {
      $global:DropBoxBaseDir = 'C:\Dropbox\'
      $global:OneDriveBaseDir = 'C:\OneDrive\'
      #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      #$nPSModulePath = $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      break
    }
    'ncat-ltb1' {
      $global:DropBoxBaseDir = 'D:\Dropbox\'
      $global:OneDriveBaseDir = 'C:\OneDrive\'
      #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      #$nPSModulePath = $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      break
    }
    'ncat-lt0' {
      # The name of the dropbox admin
      $global:DropBoxBaseDir = 'C:\Dropbox\'
      $global:OneDriveBaseDir = 'C:\OneDrive\'
      #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      #$nPSModulePath = $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      break
    }
    'dev\d*' {
      # The name of the dropbox admin
      $global:DropBoxBaseDir = 'D:\Dropbox\'
      $global:OneDriveBaseDir = 'D:\OneDrive\'
      #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      #$nPSModulePath = $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      break
    }
    'utat\d*' {
      # The name of the dropbox admin
      $global:DropBoxBaseDir = 'C:\Dropbox\'
      $global:OneDriveBaseDir = 'C:\OneDrive\'
      #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      #$nPSModulePath = $DropBoxBaseDir +'Dev\AT\WindowsPowerShell\Modules'
      break
    }
    default {
      # None of the other computers should have cloud loaded
      $global:DropBoxBaseDir = 'C:\Dropbox\'
      $global:OneDriveBaseDir = 'C:\OneDrive\'
    }
  }
}
if ($true) {Set-CloudDirectoryLocations}

# Set the PSModulePath
# different for Powershell V7 and anything earlier (PowerShell for Windows)
if ($PSVersionTable.PSVersion.major -ge 7) {
	$Env:PSModulePath = (join-path $env:ProgramFiles "PowerShell\Modules") + ';' + $Env:PSModulePath
} else {
	#$Env:PSModulePath = (join-path $env:ProgramFiles "WindowsPowerShell\Modules") + ';' + $Env:PSModulePath
}
Write-Verbose ("Final PSModulePath profile is: " + "`r`n`t" + (($Env:PSModulePath -split ';') -join "`r`n`t"))

# Add MSBuild path to path
$env:path += ';C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin'
# Add ATAP.Utilites Powershell path to path
$env:path += ';C:\Dropbox\whertzing\GitHub\ATAP.Utilities\ATAP.Utilities.BuildTooling.PowerShell'

# temporary
#todo: solve the puzzle why my own modules won't autoload
Write-Verbose ("PsScriptRoot: $psScriptRoot")

Import-Module c:\Dropbox\whertzing\PowerShell\Modules\ATAP.Utilities.PowerShell\0.1.0\ATAP.Utilities.PowerShell.psm1 -force -verbose
Import-Module c:\Dropbox\whertzing\PowerShell\Modules\ATAP.Utilities.FileIO.PowerShell\0.1.0\ATAP.Utilities.FileIO.PowerShell.psm1 -force -verbose
Import-Module c:\Dropbox\whertzing\PowerShell\Modules\ATAP.Utilities.BuildTooling.PowerShell\0.1.0\ATAP.Utilities.BuildTooling.PowerShell.psm1 -force -verbose

# Is this script elevated
$elevatedSIDPattern='S-1-5-32-544|S-1-16-12288'
if ((whoami /all) -match $elevatedSIDPattern) {Write-Verbose "Elevated permisions"}#ToDo; change window border to yellow}

# Show environment/context information when the profile runs
# ToDo reformat using YAML
Function Show-context{
  # Print the version of the framework we are using
  Write-Verbose ("Framework being used: {0}" -f [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())
  Write-Verbose ("DropBoxBaseDir: {0}" -f $global:DropBoxBaseDir)
  Write-Verbose ("PSModulePath: {0}" -f $Env:PSModulePath)
  Write-Verbose ("Elevated permisions:" -f (whoami /all) -match $elevatedSIDPattern)
  Write-Verbose ("Drops:{0}" -f $($drops | format-table | out-string))
  #DebugPreference
  #VerbosePreference
  #LoggingFrameworkandLogFileLocation
  # ConssoleSettings
  
}
if ($true) {Show-context}


# https://stackoverflow.com/questions/138144/what-s-in-your-powershell-profile-ps1-file
filter match( $reg )
{
    if ($_.tostring() -match $reg)
        { $_ }
}

# behave like a grep -v command
# but work on objects
filter exclude( $reg )
{
    if (-not ($_.tostring() -match $reg))
        { $_ }
}

# behave like match but use only -like
filter like( $glob )
{
    if ($_.toString() -like $glob)
        { $_ }
}

filter unlike( $glob )
{
    if (-not ($_.tostring() -like $glob))
        { $_ }
}

<# To Be Moved Somewhere else #>

<#
Function list-music {
param ($dir = 'D:\dropbox\music',$numcolumns = 1, $pagewidth=180)
$r=@{discards=@();duplicates=@();keep=@()}
$foundfns = @();
$rawcnt=0
gci -r $dir | ?{($_.PSisContainer -eq $false)} | %{$fh=$_
  $rawcnt++;
  if ($_.name -match '(tunebite)') {
    $r.discards += $fh.fullname
  }
  elseif (($_.extension -match '(jpg|itc2|ipa)') -or ($_.length -eq 0)) {
    $r.discards += $fh.fullname
  }
  else {
    if ($true) {
    } else {
    }
    $r.keep += $fh.fullname
  }
}
$r| ?{($_.name -notmatch '(tunebite|itune)') -and ($_.PSisContainer -eq $false) -and ($_.extension -notmatch '(jpg|itc2|ipa)' -and ($_.length -gt 0))
} | select -expandproperty fullname | %{$_ -replace [System.Text.RegularExpressions.Regex]::Escape($dir),''} )
$b=@()
for ($i=0;$i -lt $a.length;$i++) {
  $imod = $i % $numcolumns
  $idiv = [math]::floor($i/$numcolumns)
  if ($imod  -eq 0) {$t=@{};for ($j=0;$j -lt $numcolumns;$j++){$t.$j=''}; $b +=$t}
  ($b[$idiv])[$imod] = $a[$i]
}
$colwidth = [math]::floor($pagewidth/$numcolumns)
#$b|format-table -Wrap -HideTableHeaders
$strary = @() 
$b | %{$t=$_
  $str = ''
  for ($j=0;$j -lt $numcolumns;$j++){
    $str+= "{0,-$colwidth}" -f $t[$j]
  }
  $strary +=$str
}
$strary
}
#>
<#
Function get-emptydirs {
param ($dir = 'D:\dropbox\music\')
  $a = Get-ChildItem $dir -recurse | Where-Object {$_.PSIsContainer -eq $True}
  $a | Where-Object {$_.GetFiles().Count -eq 0} | Select-Object Fullname 
}
#>
# Read in an external Settings file from the same dir where the running script resides
#  This will look for Settings.Profile.ps1 by default
# Get-Settings 'C:\Dropbox\ATAP\Customers\Travelocity\Cfg\Prd\PowershellProfile\Settings.Profile.ps1'
# Import the RDPFromCommandLine module, which expects the current list of tealeaf servers 
# ipmo RDPFromCommandLine
# Define the RDP Settings file path for Travelocity servers
# $Settings.RDPConnectionPathBase = 'C:\Dropbox\ATAP\Customers\Travelocity\Cfg\Prd\{0}RDPSettings.rdp'
<#
Function New-PlantUML {
  param ($args)
  start java -jar "C:\ProgramData\chocolatey\lib\plantuml\tools\plantuml.jar" ""$args""
}
New-Alias graph New-PlantUML

#>


