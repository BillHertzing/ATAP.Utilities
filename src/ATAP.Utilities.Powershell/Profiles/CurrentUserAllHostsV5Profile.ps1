<#
.SYNOPSIS
PowerShell V5 profile template for individual users
.DESCRIPTION
Details in [powerShell ReadMe](src\ATAP.Utilities.Powershell\Documentation\ReadMe.md)

.INPUTS
None
.OUTPUTS
None
.EXAMPLE
None
.LINK
http://www.somewhere.com/attribution.html
.LINK
<Another link>
.ATTRIBUTION
<Where the ideas came from>
.SCM
<Configuration Management Keywords>
#>

# Set Verbosity and Debug preferences for this profile
$oldVerbosePreference = $script:VerbosePreference (
$script:VerbosePreference
########################################################
# Individual PowerShell Profile
########################################################

$settings={
  dummy:'dummy'
}
#Get-Settings $SettingsFile

if ($settings.IsElevated) { Write-Verbose 'Elevated permisions' }
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


# Expand upon the PSModulePath according to the roles this user has on this machine# ToDo: expand the use of PSModulepAth in the globals settings files
# extract all the psmodulepath items from the global:Settings
# The following ordered list of module paths come from ATAP and 3rd-party modules that correspond to roles of this user on this machine
$UserPSModulePaths = @(

  # ATAP Powershell is part of the machine profile
  # 'Modules that are in DevelopmentLifecycle Phase, for which I am involved'
  # 'Modules that are in Unit Test Lifecycle Phase, for which I am involved ("I" may be a user or a CI/CD service)'
  # 'Modules that are in Integration Test Lifecycle Phase, for which I am involved'
  # 'Modules that are in RTM Lifecycle Phase, for which I am involved'
  # 'All Production modules for Scripts I use day-to-day' - These should reference modules in
  # Image manipulation scripts for blog posts
  # DropBox api scripts for blog posts
  # Future: scripts to manipulate FreeVideoEditor VSDC
  # the default location where chocolatey installs modules on this machine
  $global:Settings[$global:configRootKeys['ChocolateyLibDirConfigRootKey']]
)
# Add the $UserPSModulePaths to the exisiting $env:PSModulePaths
$desiredPSModulePaths = $UserPSModulePaths  + $($Env:PSModulePath -split [IO.Path]::PathSeparator)
# Set the $Env:PsModulePath to the new value of $desiredPSModulePaths.
[Environment]::SetEnvironmentVariable('PSModulePath', $desiredPSModulePaths -join [IO.Path]::PathSeparator, 'Process')


# Clean up the $desiredPSModulePaths
# The use of 'Get-PathVariable' function causes the pcsx module to be loaded here
# ToDo: work out pscx for jenkins clinet agents
#$finalPSModulePaths = Get-PathVariable -Name 'PSModulePath' -RemoveEmptyPaths -StripQuotes
# Set the $Env:PsModulePath to the final, clean value of $desiredPSModulePaths.
#[Environment]::SetEnvironmentVariable('PSModulePath', $finalPSModulePaths -join [IO.Path]::PathSeparator, 'Process')

# Any machine that has openssl installed, needs to add it's path to the machine-scope path
# This should only be done once, by a machine admin, when it is installed onto a machine


#$Env:PSModulePath = (join-path $env:ProgramFiles "WindowsPowerShell\Modules") + [IO.Path]::PathSeparator + $Env:PSModulePath
"Final PSModulePath in AlluserAllshell profile is: " + "`r`n`t" + (($Env:PSModulePath -split [IO.Path]::PathSeparator) -join "`r`n`t")

# Is this script elevated
$elevatedSIDPattern='S-1-5-32-544|S-1-16-12288'
if ((whoami /all) -match $elevatedSIDPattern) {Write-Verbose "Elevated permisions"}#ToDo; change window border to yellow}

# Show environment/context information when the profile runs
# ToDo reformat using YAML
Function Show-context{
  # Print the version of the framework we are using
  Write-Verbose ("Framework being used: {0}" -f [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())
  Write-Verbose ("DropBoxBasePath: {0}" -f $global:DropBoxBasePath)
  Write-Verbose ("PSModulePath: {0}" -f $Env:PSModulePath)
  Write-Verbose ("Elevated permisions:" -f (whoami /all) -match $elevatedSIDPattern)
  Write-Verbose ("Drops:{0}" -f $drops)
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
  Start-Process $global:settings[$global:configRootKeys['JavaExePathConfigRootKey']] -jar "C:\ProgramData\chocolatey\lib\plantuml\tools\plantuml.jar" ""$args""
}
New-Alias graph New-PlantUML

#>


