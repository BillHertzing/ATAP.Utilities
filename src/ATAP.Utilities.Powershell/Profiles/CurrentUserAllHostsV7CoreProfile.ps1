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
# if ($global:settings.Contains($global:configRootKeys['EncryptedMasterPasswordsPathConfigRootKey'])) {
#   $path = $global:settings[$global:configRootKeys['EncryptedMasterPasswordsPathConfigRootKey']]
#   # if the value is not $null
#   if ($path ) {
#     $name = 'MyPersonalSecrets'
#     Unlock-UsersSecretStore -Name $name -EncryptedMasterPasswordsPath $path
#   }
# }

# examples of subject # 'CN=$HostName,OU=$OrganizationalUnit,O=$Organisation,L=$Locality,S=$State,C=$CountryName,E=$Email'
# $DataEncryptionCertificateTemplatePath = 'C:\DataEncryptionCertificate.template'  # Keep this out of the repository, but will be machine/user dependent

# Create Data Encryption certificates for all the SecretManagement Extension Vaults (to be done once by admins,and updated on vault CRUD)
# Install the Data Encryption certificates that belong to a user's roles on a local machine (to be done once by admins)
# Create-EncryptedMasterPasswordsFile -path $SecretManagementExtensionVaultEncryptedMasterPasswordsPath -SecretManagementExtensionVaults $SecretManagementExtensionVaults -SecureTempBasePath ($global:Settings[$global:configRootKeys['SecureTempBasePathConfigRootKey']]) -DataEncryptionCertificateTemplatePath $DataEncryptionCertificateTemplatePath -DataEncryptionCertificateRequestSecondPart $DataEncryptionCertificateRequestSecondPart -DataEncryptionCertificateSecondPart $DataEncryptionCertificateSecondPart

# Create all the SecretManagement Extension Vaults (to be done once by admins,and updated on vault CRUD)
# Just the first vault (SecretVault only support a single vault see https://github.com/PowerShell/SecretStore/issues/58)

#$SecretManagementExtensionVaults[0] New-SecretManagementExtensionVault

# Get the Vaults and Master Passwords for the Secrets that belong to my roles




# This is a developer profile, so Import Developer BuildTooling For Powershell
#. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\public\Get-ModuleAsSymbolicLink.ps1'

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
  # Security Administration powershell modules that enable administrators, users and ServiceAccounts to access secrets and certificates
  [PSCustomObject]@{
    Name          = 'ATAP.Utilities.Security.Powershell'
    Version       = '0.1.0'
    SourcePath    = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell'
    usePreRelease = $true
  },
  # Useful Functions specific to FileIO
  [PSCustomObject]@{
    Name          = 'ATAP.Utilities.FileIO.PowerShell'
    Version       = '0.1.0'
    SourcePath    = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.FileIO.PowerShell'
    usePreRelease = $true
  },
  # Useful Functions specific to Neo4j
  [PSCustomObject]@{
    Name          = 'ATAP.Utilities.Neo4j.Powershell'
    Version       = '0.1.0'
    SourcePath    = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Neo4j.Powershell'
    usePreRelease = $true
  })

# Create symbolic links to each of the modukles above in the user's default powershell module location
# The function uses Join-Path ([Environment]::GetFolderPath('MyDocuments')) '\PowerShell\Modules\' as the default PSModulePath path
# $ModulesToLoadAsSymbolicLinks | Get-ModuleAsSymbolicLink

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

# Set an alias to tail the latest PSFramework log file
function TailLatestPSFrameworkLog {
  (Get-Content ((Get-ChildItem C:\Users\whertzing\AppData\Roaming\PowerShell\PSFramework\Logs) | Sort-Object -Property 'lastwritetime' -desc)[0] )[-100..-1]
}
Set-Alias -Name 'tail' -Value 'TailLatestPSFrameworkLog'

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
Function getconflictedGCI { Get-ChildItem -Recurse . -Include *conflicted*.* }
Function getconflictedES { es conflicted }

Function FindFilesByES {
  [CmdletBinding(DefaultParameterSetName = 'StringParameter')]
  param(
    [parameter(ParameterSetName = 'StringParameter', Mandatory = $true, Position = 1, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] [string] $searchStr
    , [parameter(ParameterSetName = 'RegExParameter', Mandatory = $true, Position = 1, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] [Regex] $searchRE
    #, $path = 'C:\Dropbox\whertzing\'
  )
  [string] $internalSearchStr = ''
  [regex] $internalSearchRegex = ''
  switch ($PSCmdlet.ParameterSetName) {
    StringParameter {
      # ToDo: continously improve validate user input for safety
      $internalSearchStr = $searchStr
      es $internalSearchStr
    }
    RegExParameter {
      # ToDo: continously improve validate user input for safety
      $internalSearchRegex = $searchRE
      es regex: $internalSearchRegex
    }
  }
  es regex: $internalSearchRegex
}

Function Get-Attributions {
  Param(
    $path = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\*'
    , $include = ('*.ps1', '*.md')
    , [switch] $Recurse
  )
  $findRegex = [Regex] '\[\s*(?<Title>.*?)\s*\]\s*\(\s*(?<URL>.*?)\s*\)\s*'
  $files = if ($Recurse) { Get-ChildItem -Path $path -Include $include -Recurse } else { Get-ChildItem -Path $path -Include $include }
  foreach ($fh in $files) {
    $FileStream = New-Object 'System.IO.FileStream' $fh, 'Open', 'Read', 'ReadWrite'
    $reader = New-Object 'System.IO.StreamReader' $FileStream
    try {
      while (!$reader.EndOfStream) {
        $line = $reader.ReadLine()
       [RegEx]::Matches($line, $findRegex)
        if ($Matches.Success) {
          [PSCustomObject]@{
            Fullpath = $fh.fullname
            Title    = $matches['Title']
            URL      = $matches['URL']
          }
        }
      }
    }
    finally {
      $reader.Close()
      $FileStream.Close()
    }
  }
}
Function Get-LinksFromDrafts {
  Param(
    $path = 'C:\Temp\gmaildrafts\Takeout\Mail\Drafts.mbox'
  )
  $DebugPreference = 'SilentlyContinue'
  $Stream = New-Object 'System.IO.FileStream' $path, Open, Read, ReadWrite
  $reader = New-Object 'System.IO.StreamReader' $Stream
  $findRegex1 = [Regex] '^Subject:\s*(?<Subject>.*?)$'
  $findRegex2 = [Regex] '(?i)^(?<URL>http.*)'
  $Subject = ''
  $URL = ''
  $cnt = 0
  try {
    while (!$reader.EndOfStream) {
      # ToDO: add Progress Reporting
      if (-not ($cnt % 100000)) {Write-PSFMessage -Level Debug -Message "cnt = $cnt" }
      $cnt += 1
      #if ($cnt -gt 2000) {throw}
      $line = $reader.ReadLine()
      $matchResult = [RegEx]::Matches($line, $findRegex1)
      if ($matchResult.Success) {
        $Subject = $matchResult.captures.groups['Subject'].value
        #Write-PSFMessage -Level Debug -Message "Subject = $Subject"
      } else {
        $matchResult = [RegEx]::Matches($line, $findRegex2)
        if ($matchResult.Success) {
          $URL = $matchResult.captures.groups['URL'].value
          #Write-PSFMessage -Level Debug -Message "URL = $URL"
        }
      }
      if ($subject -and $URL) {
        $obj =  [PSCustomObject]@{
          Fullpath = 'Drafts'
          Title    = $Subject
          URL      = $URL
        }
        write-output $obj
        $Subject = ''
        $URL = ''
      }
    }
  }
  finally {
    $reader.Close()
    $Stream.Close()
  }
}

if ($false) {
$delegateDistinctURL = [Func[PSCustomObject, string]] { param([PSCustomObject]$o); return $o.URL }
$a = [Linq.Enumerable]::ToArray([Linq.Enumerable]::DistinctBy([PSCustomObject[]]$(Get-LinksFromDrafts),$delegateDistinctURL ))
}
Function Get-AllBookmarks {
  foreach ($o in $($(Get-BrowserBookmarks '*' '*') | Sort-Object -Property URL -uniq)) {
    [PSCustomObject]@{
      Fullpath = 'BrowserBookmarksAllBrowsersAllBookmarks'
      Title    = $o.Title
      URL      = $o.URL
    }
  }
}

# Get-Attributions -path 'C:\Dropbox\' -Recurse | convertto-json | out-file 'C:\Dropbox\AllAttributions.txt'
Function Get-LinksFiltered {
  Param(
    $path = 'C:\Dropbox\whertzing\'
    , $include = ('*.ps1', '*.md')
    , [regex] $findRegex
    , [switch] $Recurse

  )

  # fetch alllinks from the link's persistence locations
  #$alllinks = Get-AllBookmarks
  #$alllinks += Get-Attributions -path $path -Recurse
  $alllinks = foreach ($o in $(Get-Content -Path 'C:\Dropbox\whertzing\AllComputerBrowserbookmarks_20220510.txt' | ConvertFrom-Json -AsHashtable)) { [PSCustomObject]@{URL = $o.URL; TITLE = $o.Title } }
  $alllinks += foreach ($o in $(Get-Content -Path 'C:\Dropbox\whertzing\AllAttributions.txt' | ConvertFrom-Json -AsHashtable)) { [PSCustomObject]@{URL = $o.URL; TITLE = $o.Title } } # Get-Attributions -path $path -Recurse
  # $acc = @{
  #   Time1    = ''
  #   Time2    = ''
  #   Count1   = ''
  #   Count2   = ''
  #   results1 = @()
  #   results2 = @()
  # }
  # $acc['time1'] = Measure-Command {
  #   foreach ($l in $alllinks) {
  #     if (($l.Title -match $findRegex) -or ($l.URL -match $findRegex) ) {
  #       $acc['results1'] += $l
  #     }
  #   }
  # }
  # $acc.Count1 = $($acc['results1']).count

  # $acc['time2'] = Measure-Command {
    # eliminate any search engine urls
    $SERegEx = [regex] 'search\.brave\.com'
  $delegateRegexMatch = [Func[PSCustomObject, bool]] { param([PSCustomObject]$o); return ((($findRegex.Match($o.title)).Success -or ($findRegex.Match($o.URL)).Success) -and -not ($SERegEx.Match($o.URL)).Success) }
  $delegateDistinctURL = [Func[PSCustomObject, string]] { param([PSCustomObject]$o); return $o.URL }
  $query=[PSCustomObject[]] [Linq.Enumerable]::Where([PSCustomObject[]]$alllinks, [Func[PSCustomObject, bool]] $delegateRegexMatch)
  $distinctMatchedQuery = [Linq.Enumerable]::DistinctBy( [PSCustomObject[]] $query,  $delegateDistinctURL)
  return  [Linq.Enumerable]::ToArray([PSCustomObject[]]$distinctMatchedQuery)
}

# foreach ($o in $(Get-Attributions -Recurse)) {"[$($o.Title)]($($o.URL))" }
Function Open-FilteredLinksInBrave {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'StringParameter')]

  Param(
    [parameter(ParameterSetName = 'StringParameter', Mandatory = $true, Position = 1, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] [string] $reStr
    , [parameter(ParameterSetName = 'RegExParameter', Mandatory = $true, Position = 1, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)] [Regex] $re
    , $path = 'C:\Dropbox\whertzing\'
    , $include = ('*.ps1', '*.md')
  )
  [regex] $findRegex = ''
  switch ($PSCmdlet.ParameterSetName) {
    StringParameter {
      # ToDo: continously improve validation of user input for safety
      $validatedStr = $reStr # [regex]::Escape($reStr)
      $findRegex = [regex] $validatedStr
    }
    RegExParameter {
      # ToDo: continously improve validation of user input for safety
      $findRegex = $re
    }
  }
  $links = $(Get-LinksFiltered -Path $path -Include $include -findRegex $findRegex -Recurse).URL
  Start-Process 'brave.exe' -ArgumentList '--new-window', $($links -join ' ')
}

# [regex] $re = = '(?ism)(openssl|509)'
# Open-FilteredLinksInBrave -path 'C:\Dropbox\whertzing\GitHub\atap.utilities' -findRegex $re
# Alias FindAndOpenLinks
Set-Alias -Name FAOL -Value Open-FilteredLinksInBrave

# faol $([regex] '(x509|signing|openssl|certificate)')
# A Function to use a FileWatcher asynchronously to detect when a file is changed
Function WatchFile {
  params(
    [ValidateScript({ Test-Path $_ })]
    [string] $path
  )
  # [FileSystemWatcher Monitoring Folders for File Changes](https://powershell.one/tricks/filesystem/filesystemwatcher)

  # specify the path to the folder you want to monitor:
$ParentPath = Split-Path $path

# specify which file(s) you want to monitor
$FileFilter = Split-Path $path -PathType Leaf

# specify whether you want to monitor subfolders as well:
$IncludeSubfolders = $false

# specify the file or folder properties you want to monitor:
$AttributeFilter = [IO.NotifyFilters]::LastWrite

try
{
  $watcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
    Path = $ParentPath
    Filter = $FileFilter
    IncludeSubdirectories = $IncludeSubfolders
    NotifyFilter = $AttributeFilter
  }

  # define the code that should execute when a change occurs:
  $action = {
    # the code is receiving this to work with:

    # change type information:
    $details = $event.SourceEventArgs
    $Name = $details.Name
    $FullPath = $details.FullPath
    $OldFullPath = $details.OldFullPath
    $OldName = $details.OldName

    # type of change:
    $ChangeType = $details.ChangeType

    # when the change occured:
    $Timestamp = $event.TimeGenerated

    # save information to a global variable for testing purposes
    # so you can examine it later
    # MAKE SURE YOU REMOVE THIS IN PRODUCTION!
    $global:all = $details

    # now you can define some action to take based on the
    # details about the change event:

    # you can also execute code based on change type here:
    switch ($ChangeType)
    {
      'Changed'  { "CHANGE" }
      'Created'  { "CREATED"}
      'Deleted'  { "DELETED"
        # to illustrate that ALL changes are picked up even if
        # handling an event takes a lot of time, we artifically
        # extend the time the handler needs whenever a file is deleted
        Write-Host "Deletion Handler Start" -ForegroundColor Gray
        Start-Sleep -Seconds 4
        Write-Host "Deletion Handler End" -ForegroundColor Gray
      }
      'Renamed'  {
        # this executes only when a file was renamed
        $text = "File {0} was renamed to {1}" -f $OldName, $Name
        Write-Host $text -ForegroundColor Yellow
      }

      # any unhandled change types surface here:
      default   { Write-Host $_ -ForegroundColor Red -BackgroundColor White }
    }
  }

  # subscribe your event handler to all event types that are
  # important to you. Do this as a scriptblock so all returned
  # event handlers can be easily stored in $handlers:
  $handlers = . {
    Register-ObjectEvent -InputObject $watcher -EventName Changed  -Action $action
    Register-ObjectEvent -InputObject $watcher -EventName Created  -Action $action
    Register-ObjectEvent -InputObject $watcher -EventName Deleted  -Action $action
    Register-ObjectEvent -InputObject $watcher -EventName Renamed  -Action $action
  }

  # monitoring starts now:
  $watcher.EnableRaisingEvents = $true

  Write-Host "Watching for changes to $Path"

  # since the FileSystemWatcher is no longer blocking PowerShell
  # we need a way to pause PowerShell while being responsive to
  # incoming events. Use an endless loop to keep PowerShell busy:
  do
  {
    # Wait-Event waits for a second and stays responsive to events
    # Start-Sleep in contrast would NOT work and ignore incoming events
    Wait-Event -Timeout 1

    # write a dot to indicate we are still monitoring:
    Write-Host "." -NoNewline

  } while ($true)
}
finally
{
  # this gets executed when user presses CTRL+C:

  # stop monitoring
  $watcher.EnableRaisingEvents = $false

  # remove the event handlers
  $handlers | ForEach-Object {
    Unregister-Event -SourceIdentifier $_.Name
  }

  # event handlers are technically implemented as a special kind
  # of background job, so remove the jobs now:
  $handlers | Remove-Job

  # properly dispose the FileSystemWatcher:
  $watcher.Dispose()

  # Caution - if tailing the debug log, this would cause an endless loop
  Write-PSFMessage -Level Debug -Message ("Event Handler disabled, monitoring ends.")

}
}

#  A Function to tail the last N lines of the PSFramework log
Function TailLog {
  param (
    [string] $file
    ,[int]$numlines = 20
    ,[switch] $wait
    )
    # if file was not supplied, use the PSFramework logging filesystem logpath, and get the most recent file there
    if (-not ($PSBoundParameters.ContainsKey('file'))) {
    $file = (Get-ChildItem $(Get-PSFConfigValue -FullName PSFramework.Logging.FileSystem.LogPath) | Sort-Object -Property LastWriteTime -Descending)[0]
    }
    $command = "Get-Content -Path $file -tail $numlines"
    iex $command
    if ($wait) {
      # Create a callback function that will tail the last N lines of the file
      # attach a file watcher (on file modified) to the file with the callback as the action
      # stay in this function until the user enters ctrl-c
    }
  }
# A function to stop PushBullet processes
function KillPushBullet {Get-Process | Where-Object{$_.processname -match 'pushbul'}  | stop-process}

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


# A function to get the Windows Security Identifier (SID) given a user name
Function GetSIDfromAcctName
{
  [CmdletBinding(DefaultParameterSetName = 'Local')]

    Param(
        [Parameter(mandatory=$true)]$userName
        , [Parameter(ParameterSetName = 'Remote')]
        [Parameter(mandatory=$false)]$ComputerName
    )
    $usracct = ''
    $command = 'Get-CimInstance -Query "Select * from Win32_UserAccount where name = ''$userName''"'
    switch ($PSCmdlet.ParameterSetName) {
      Local {
          # No change to the basee command
      }
      Remote {
        $command = $command + " -ComputerName $ComputerName"
      }
    }
    Write-PSFMessage -Level Debug -Message "command = $command"
    $usracct = Invoke-Expression $command
    return $usracct.sid
}

# A function to set an environment variable for a named user (at the user scope in the machine's registry)
# must be run in an elevated (administrator) process

# Get the registry entry for HKey_users\$sid\Environment
# if the desired environment variable does not exist as a key, create the key as a string
# Set the value of the environment variable (Key)



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
Write-PSFMessage -Level Debug -Message ('After CurrentUsersAllHosts profile executes, global:settings:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:settings ($indent + $indentIncrement) $indentIncrement) + '}' + [Environment]::NewLine )
Write-PSFMessage -Level Debug -Message ('After CurrentUsersAllHosts profile executes, Environment variables: ' + [Environment]::NewLine + (Write-EnvironmentVariablesIndented ($indent + $indentIncrement) $indentIncrement) + [Environment]::NewLine )

Set-Location 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'


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


