<#
.SYNOPSIS
PowerShell V7 profile template for individual users
.DESCRIPTION
Settings specific for a user, whose values represent the tasks and environments the user is doing
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
[Customize Prompt](https://www.networkadm.in/customize-pscmdprompt/) adding info to the prompt and terminal window
ToDo: Need attribution for IsElevated = ((whoami /all) -match $'S-1-5-32-544|S-1-16-12288') Magic SId's
ToDo: Need attribution for Console Settings
<Where the ideas came from>
.SCM
<Configuration Management Keywords>
#>

# Set these for debugging the profile
# Don't Print any debug messages to the console
$DebugPreference = 'SilentlyContinue'
# Don't Print any verbose messages to the console
$VerbosePreference = 'SilentlyContinue' # SilentlyContinue Continue

#ToDo: document expected values when run under profile, Module cmdlet/function, script.
Write-Verbose "Starting $($MyInvocation.Mycommand)"
Write-Verbose ("WorkingDirectory = $pwd")
Write-Verbose ("PSScriptRoot = $PSScriptRoot")

# Add MSBuild path to path
#$env:path += ';C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin'
# Add ATAP.Utilites Powershell path to path
#$env:path += ';C:\Dropbox\whertzing\GitHub\ATAP.Utilities\ATAP.Utilities.BuildTooling.PowerShell'



########################################################
# Individual PowerShell Profile
########################################################

# [powerShell ReadMe](src\ATAP.Utilities.Powershell\Documentation\ReadMe.md for details)

# Store the current directory, where the profile was started from...
$storedInitialDir = pwd

# Setup Logging for script execution and debugging, after settings are processed
#$LogFn =$settings.LogFnPath + $settings.LogFnPattern;
#Init-Log4Net $LogFn

# Things to be initialized after settings are processed
# TBD

##############################
# Console Settings
##############################
# Number of commands to keep in the commandHistory
$global:MaxHistoryCount = 1000

# Size of the console's user interface
Function ConsoleSettings {
  $console = $host.ui.Rawui
  ($console.BufferSize).width = 200
  ($console.BufferSize).height = 3000
  ($console.windowSize).width = 200
  ($console.windowSize).height = 100
  ($console.WindowTitle) = "Current Folder: $pwd"
  # ToDo; change window border to yellow if IsElevated is true, but see https://github.com/vercel/hyper/issues/4529 and https://github.com/microsoft/terminal/issues/1859 for discussion
}
if ($host.ui.Rawui.WindowTitle -notmatch 'ISE') { ConsoleSettings }

Function prompt {
  #Assign Windows Title Text
  $host.ui.RawUI.WindowTitle = "Current Folder: $pwd"

  #Configure current user, current folder and date outputs
  $CmdPromptCurrentFolder = Split-Path -Path $pwd -Leaf
  $CmdPromptUser = [Security.Principal.WindowsIdentity]::GetCurrent();
  # Decorate the CMD Prompt
  # Test for Admin / Elevated
  #Write-Host ''
  Write-Host ($(if ($global:settings[$global:configRootKeys['IsElevatedConfigRootKey']]) { 'Elevated ' } else { '' })) -BackgroundColor DarkRed -ForegroundColor White -NoNewline

  Write-Host " USER:$($CmdPromptUser.Name.split('\')[1]) " -BackgroundColor DarkBlue -ForegroundColor White -NoNewline
  If ($CmdPromptCurrentFolder -like '*:*')
  { Write-Host " $CmdPromptCurrentFolder " -ForegroundColor White -BackgroundColor DarkGray -NoNewline }
  else { Write-Host ".\$CmdPromptCurrentFolder\ " -ForegroundColor White -BackgroundColor DarkGray -NoNewline }
  return '> '
}

# set the Cloud Location variables for THIS user
# Function Set-CloudDirectoryLocations {
#   switch -regex ($env:computername) {
#     'ncat016' {
#       $global:settings[$global:Conf ]
#       $global:DropBoxBasePath = 'C:\Dropbox\'
#       $global:OneDriveBaseDir = 'C:\OneDrive\'
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'ncat040' {
#       $global:DropBoxBasePath = 'C:\Dropbox\'
#       $global:OneDriveBaseDir = 'C:\OneDrive\'
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'ncat-ltjo' {
#       $global:DropBoxBasePath = 'C:\Dropbox\'
#       $global:OneDriveBaseDir = 'C:\OneDrive\'
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'ncat-ltb1' {
#       $global:DropBoxBasePath = 'D:\Dropbox\'
#       $global:OneDriveBaseDir = 'C:\OneDrive\'
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'ncat-lt0' {
#       # The name of the dropbox admin
#       $global:DropBoxBasePath = 'C:\Dropbox\'
#       $global:OneDriveBaseDir = 'C:\OneDrive\'
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'dev\d*' {
#       # The name of the dropbox admin
#       $global:DropBoxBasePath = 'D:\Dropbox\'
#       $global:OneDriveBaseDir = 'D:\OneDrive\'
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'utat\d*' {
#       # The name of the dropbox admin
#       $global:DropBoxBasePath = 'C:\Dropbox\'
#       $global:OneDriveBaseDir = 'C:\OneDrive\'
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     default {
#       # None of the other computers should have cloud loaded
#       $global:DropBoxBasePath = 'C:\Dropbox\'
#       $global:OneDriveBaseDir = 'C:\OneDrive\'
#     }
#   }
# }
# if ($true) { Set-CloudDirectoryLocations }


Write-Verbose ("PsScriptRoot: $psScriptRoot")

# The following ordered list of module paths come from ATAP and 3rd-party modules that have been selected by this user
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
    )


# This is a developer profile, so Import Developer BuildTooling For Powershell
#. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-ModulesForUserProfileAsSymbolicLinks.ps1'

# These are the powershell Modules I'm working on now
$ModulesToLoadAsSymbolicLinks = @(
  # User Functions
  [PSCustomObject]@{
    Name = 'ATAP.Utilities.PowerShell'
    Version = '0.1.0'
    SourcePath  = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell'
    usePreRelease = $true
  },
  # Developer and CI/CD powershell modules that assist developers creating code and building it, and modules shared with the CI/CD
  [PSCustomObject]@{
    Name = 'ATAP.Utilities.BuildTooling.PowerShell'
    Version = '0.1.0'
    SourcePath  = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.Powershell'
    usePreRelease = $true
  },
  # Useful Functions specific to FileIO
  [PSCustomObject]@{
    Name = 'ATAP.Utilities.FileIO.PowerShell'
    Version = '0.1.0'
    SourcePath  = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FileIO.PowerShell'
    usePreRelease = $true
  })

  # Create symbolic links to each of the modukles above in the user's default powershell module location
  # The function uses Join-Path ([Environment]::GetFolderPath('MyDocuments')) '\PowerShell\Modules\' as the default PSModulePath path
  $ModulesToLoadAsSymbolicLinks | Get-ModuleAsSymbolicLink

# Print the global settings, indented
(get-item  variable:\settings).Value.keys | sort | %{$key = $_; if ((get-item  variable:\settings).Value.$key  -is [System.Collections.IDictionary]) {"$key yep"}else {"$key = $($($(get-item  variable:\settings).Value).$key)"}}

# Show environment/context information when the profile runs
# ToDo reformat using YAML
Function Show-context {
  # Print the version of the framework we are using
  Write-Verbose ('Framework being used: {0}' -f [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())
  Write-Verbose ('DropBoxBasePath: {0}' -f $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]) #  $global:DropBoxBasePath)
  Write-Verbose ('PSModulePath: {0}' -f $Env:PSModulePath)
  Write-Verbose ('Elevated permisions:' -f (whoami /all) -match $elevatedSIDPattern)
  Write-Verbose ('Drops:{0}' -f $($drops | Format-Table | Out-String))
  #DebugPreference
  #VerbosePreference
  #LoggingFrameworkandLogFileLocation
  # ConsoleSettings

}
if ($true) { Show-context }

# https://stackoverflow.com/questions/138144/what-s-in-your-powershell-profile-ps1-file
filter match( $reg ) {
  if ($_.tostring() -match $reg)
  { $_ }
}

# behave like a grep -v command
# but work on objects
filter exclude( $reg ) {
  if (-not ($_.tostring() -match $reg))
  { $_ }
}

# behave like match but use only -like
filter like( $glob ) {
  if ($_.toString() -like $glob)
  { $_ }
}

filter unlike( $glob ) {
  if (-not ($_.tostring() -like $glob))
  { $_ }
}

# A function that will set-Location to 'MyDocuments`
Function cdMy {$x= [Environment]::GetFolderPath('MyDocuments');Set-Location -Path $x}

# A function that will return files with names matching the string 'conflicted'
Function getconflicted {gci  -Recurse. | where-object -property fullname -match 'conflicted'}

# A function and alias to kill the VoiceAttack process
function PublishPluginAndStartVAProcess
{

  dotnet publish src/ATAP.Utilities.VoiceAttack/ATAP.Utilities.VoiceAttack.csproj /p:Configuration=Debug /p:DeployOnBuild=true /p:PublishProfile="properties/publishProfiles/Development.pubxml" /p:TargetFramework=net48 /bl:_devlogs/msbuild.binlog
  & 'C:\Users\whertzing\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\VoiceAttack.lnk'  -bypassimpropershutdowncheck
}
set-item -path alias:pSVA -value PublishPluginAndStartVAProcess

# A function and alias to kill the VoiceAttack process
function StopVoiceAttackProcess
{
  Get-Process | Where-Object {$_.Path -match 'VoiceAttack'} | Stop-Process -force
}
set-item -path alias:stopVA -value StopVoiceAttackProcess

# Final (user) directory to leave the interpreter
#cdMy
#Set-Location -Path (join-path -Path $global:DropBoxBasePath -ChildPath 'whertzing' -AdditionalChildPath 'GitHub','ATAP.Utilities')
Set-Location -Path $storedInitialDir

# Uncomment to see the $global:settings and Environment variables at the completion of this profile
#Write-Verbose ('$global:settings are: ' +  [Environment]::NewLine + (foreach ($kvp in ($global:settings).GetEnumerator()){"{0}:{1}" -f $kvp.name, $kvp.name,[Environment]::NewLine} ))
Write-Verbose ("Environment variables AllUsersAllHosts are:  " + [Environment]::NewLine + (Get-ChildItem env: |ForEach-Object{ $envVar=$_;  ('Machine','User','Process') | %{$scope = $_;
if (([System.Environment]::GetEnvironmentVariable($envVar.key, $scope))) {"{0}:{1} ({2})" -f $envVar.key, $envVar.value, $scope}
}}))


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


