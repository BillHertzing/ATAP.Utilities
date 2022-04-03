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

########################################################
# Individual PowerShell Profile
########################################################

# [powerShell ReadMe](src\ATAP.Utilities.Powershell\Documentation\ReadMe.md for details)

# Store the current directory, where the profile was started from...
$storedInitialDir = Get-Location

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
  # ToDo: change window border to yellow if IsElevated is true, but see https://github.com/vercel/hyper/issues/4529 and https://github.com/microsoft/terminal/issues/1859 for discussion
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
  Write-Host ($(if ($global:settings[$global:configRootKeys['IsElevatedConfigRootKey']]) { 'Elevated ' } else { '' })) -BackgroundColor DarkRed -ForegroundColor White -NoNewline

  Write-Host " USER:$($CmdPromptUser.Name.split('\')[1]) " -BackgroundColor DarkBlue -ForegroundColor White -NoNewline
  If ($CmdPromptCurrentFolder -like '*:*')
  { Write-Host " $CmdPromptCurrentFolder " -ForegroundColor White -BackgroundColor DarkGray -NoNewline }
  else { Write-Host ".\$CmdPromptCurrentFolder\ " -ForegroundColor White -BackgroundColor DarkGray -NoNewline }
  return '> '
}

# To use the Portable Git requires a dropbox location as the location of the global configuration file
$global:Settings[$global:configRootKeys['GIT_CONFIG_GLOBALConfigRootKey']] = 'C:\Dropbox\whertzing\Git\.gitconfig'


# The following command must be run as an administrator on the machine, to install for 'AllUsers'
# Install-ModulesPerComputer -modulesToInstall @('Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore', 'SecretManagement.KeePass')

# set the Cloud Location variables for THIS user
# Function Set-CloudDirectoryLocations {
#   switch -regex ($env:computername) {
#     'ncat016' {
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'ncat040' {
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'ncat-ltjo' {
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'ncat-ltb1' {
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'ncat-lt0' {
#       # The name of the dropbox admin
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'dev\d*' {
#       # The name of the dropbox admin
#       #$nPSModulePath = $OneDriveBaseDir + 'Customers\UAL\DEV\CFG\Utilities\Modules\;'+ $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       #$nPSModulePath = $DropBoxBasePath +'Dev\AT\WindowsPowerShell\Modules'
#       break
#     }
#     'utat\d*' {
#       # The name of the dropbox admin
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


# Unlock the user's SecretStore for this session using an encrypted password and a data Encryption Certificate installed to the current machine
# if the key exists in the global settings
if ($global:settings.Contains($global:configRootKeys['EncryptedMasterPasswordsPathConfigRootKey'])) {
  $path = $global:settings[$global:configRootKeys['EncryptedMasterPasswordsPathConfigRootKey']]
  # if the value is not $null
  if ($path ) {
    $name = 'MyPersonalSecrets'
    Unlock-UsersSecretStore -Name $name -EncryptedMasterPasswordsPath $path
  }
}

# examples of subject # 'CN=$HostName,OU=$OrganizationalUnit,O=$Organisation,L=$Locality,S=$State,C=$CountryName,E=$Email'
$DataEncryptionCertificateTemplatePath = 'C:\DataEncryptionCertificate.template'  # Keep this out of the repository, but will be machine/user dependent

# Create Data Encryption certificates for all the SecretManagement Extension Vaults (to be done once by admins,and updated on vault CRUD)
# Install the Data Encryption certificates that belong to a user's roles on a local machine (to be done once by admins)
# Create-EncryptedMasterPasswordsFile -path $SecretManagementExtensionVaultEncryptedMasterPasswordsPath -SecretManagementExtensionVaults $SecretManagementExtensionVaults -SecureTempBasePath ($global:Settings[$global:configRootKeys['SecureTempBasePathConfigRootKey']]) -DataEncryptionCertificateTemplatePath $DataEncryptionCertificateTemplatePath -DataEncryptionCertificateRequestSecondPart $DataEncryptionCertificateRequestSecondPart -DataEncryptionCertificateSecondPart $DataEncryptionCertificateSecondPart

# Create all the SecretManagement Extension Vaults (to be done once by admins,and updated on vault CRUD)
# Just the first vault (SecretVault only support a single vault see https://github.com/PowerShell/SecretStore/issues/58)

#$SecretManagementExtensionVaults[0] New-SecretManagementExtensionVault

# Get the Vaults and Master Passwords for the Secrets that belong to my roles





# This is a developer profile, so Import Developer BuildTooling For Powershell
#. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-ModulesForUserProfileAsSymbolicLinks.ps1'

# These are the powershell Modules I'm working on now
$ModulesToLoadAsSymbolicLinks = @(
  # User Functions
  [PSCustomObject]@{
    Name          = 'ATAP.Utilities.PowerShell'
    Version       = '0.1.0'
    SourcePath    = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell'
    usePreRelease = $true
  },
  # Developer and CI/CD powershell modules that assist developers creating code and building it, and modules shared with the CI/CD
  [PSCustomObject]@{
    Name          = 'ATAP.Utilities.BuildTooling.PowerShell'
    Version       = '0.1.0'
    SourcePath    = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.Powershell'
    usePreRelease = $true
  },
  # Useful Functions specific to FileIO
  [PSCustomObject]@{
    Name          = 'ATAP.Utilities.FileIO.PowerShell'
    Version       = '0.1.0'
    SourcePath    = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FileIO.PowerShell'
    usePreRelease = $true
  },
  # Useful Functions specific to FileIO
  [PSCustomObject]@{
    Name          = 'ATAP.Utilities.Neo4j.Powershell'
    Version       = '0.1.0'
    SourcePath    = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Neo4j.Powershell'
    usePreRelease = $true
  })

# Create symbolic links to each of the modukles above in the user's default powershell module location
# The function uses Join-Path ([Environment]::GetFolderPath('MyDocuments')) '\PowerShell\Modules\' as the default PSModulePath path
$ModulesToLoadAsSymbolicLinks | Get-ModuleAsSymbolicLink

# Show environment/context information when the profile runs
# ToDo reformat using YAML
Function Show-context {
  # Print the version of the framework we are using
  Write-Verbose ('Framework being used: {0}' -f [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())
  Write-Verbose ('DropBoxBasePath: {0}' -f $global:Settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]) #  $global:DropBoxBasePath)
  Write-Verbose ('PSModulePath: {0}' -f $Env:PSModulePath)
  Write-Verbose ('Elevated permisions:' -f (whoami /all) -match $elevatedSIDPattern)
  Write-Verbose ('Drops:{0}' -f $($drops | Format-Table | Out-String))
  # DebugPreference
  # VerbosePreference
  # LoggingFrameworkandLogFileLocation
  # ConsoleSettings

}
#if ($true) { Show-context }

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
Function cdMy { $x = [Environment]::GetFolderPath('MyDocuments'); Set-Location -Path $x }

# A function that will return files with names matching the string 'conflicted'
Function getconflicted { Get-ChildItem -Recurse. | Where-Object -Property fullname -Match 'conflicted' }

# A function and alias to kill the VoiceAttack process
function PublishPluginAndStartVAProcess {

  dotnet publish src/ATAP.Utilities.VoiceAttack/ATAP.Utilities.VoiceAttack.csproj /p:Configuration=Debug /p:DeployOnBuild=true /p:PublishProfile="properties/publishProfiles/Development.pubxml" /p:TargetFramework=net48 /bl:_devlogs/msbuild.binlog
  & 'C:\Users\whertzing\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\VoiceAttack.lnk' -bypassimpropershutdowncheck
}
Set-Item -Path alias:pSVA -Value PublishPluginAndStartVAProcess

# A function and alias to kill the VoiceAttack process
function StopVoiceAttackProcess {
  Get-Process | Where-Object { $_.Path -match 'VoiceAttack' } | Stop-Process -Force
}
Set-Item -Path alias:stopVA -Value StopVoiceAttackProcess

# Final (user) directory to leave the interpreter
#cdMy
#Set-Location -Path (join-path -Path $global:DropBoxBasePath -ChildPath 'whertzing' -AdditionalChildPath 'GitHub','ATAP.Utilities')
Set-Location -Path $storedInitialDir

# Always Last step - set the environment variables for this user
. (Join-Path -Path $PSHome -ChildPath 'global_EnvironmentVariables.ps1')
Set-EnvironmentVariablesProcess

# Uncomment to see the $global:settings and Environment variables at the completion of this profile
# Print the $global:settings if Debug
$indent = 0
$indentIncrement = 2
Write-Debug ('After CurrentUsersAllHosts profile executes, global:settings:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:settings ($indent + $indentIncrement) $indentIncrement) + '}' + [Environment]::NewLine )
Write-Debug ('After CurrentUsersAllHosts profile executes, Environment variables: ' + [Environment]::NewLine + (Write-EnvironmentVariablesIndented ($indent + $indentIncrement) $indentIncrement) + [Environment]::NewLine )

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


