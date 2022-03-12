# Setup a new computer

1) BIOS changes (for utat022)

  - Ensure PCIE configuration from "M2 extension card" to "dual M2 SSD"
  - Ensure SATA controllers are On
  - X.M.P is enabled
  - Intel Rapid Storage technology is OFF

  - change hotswap notification to "enabled"



unplug SATA drives, leave just PCIE drive in
disconnect from internet
Create latest Windows 11 bootable USB stick
Print latest Windows 11 Pro license Key
Install Windows 11 Pro to (unformatted) drive 0

create new user (without internet) and assign password

install Everything from USB stick, run Everything, get list to a file "01 Clean Windows 11 install, user and everything"

rename computer (utat022)
turn  off edge pre-load
get IP and MAC, for wired and wireless
wired 50-eb-f6-78-80-5a
wireless 00-91-9e-7c-45-f2
Update NetGear router DHCP leases
wired: utat022 192.168.1.22 50:EB:F6:78:80:5A wired:atap_24
Update Hosts file

update to windows 11

run Everything, get list

Create c:\Dropbox, c:\dropbox\whertzing,

Create \\Fileshare, share it with everybody on the network
Copy InstChoco and packagesconfig to Filesharecopy from fileshare to \\mydocuments\ChocolateyPackageListBackup
copy hosts to \\utat022\fileshare and then to new computer
Start Powershell (old), run Instchoco.exe as admin

Install Dropbox to c:\

Set Locations for MyDoccuments, Pictures, Videos, Downloads to c:\Dropbox-


see also C:\Dropbox\whertzing\Visual Studio 2013\Projects\CI\CI\MapUserShellFoldersToDropBox.ps1

uninstall Everything

Reinstall all chocolatey packages (includes everything)
Add to List:
  Freevideoeditor
  7zip

copy hosts

Powershell
  Run pwsh, pin to task bar
  Load the following ATAP packages
  ToDo:  - after package management
  Before package management:

  Symlink the following to C:\Program Files\PowerShell\7:
    global_MachineAndNodeSettings.ps1
    `Remove-Item -path (join-path $env:ProgramFiles '\PowerShell\7\global_MachineAndNodeSettings.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles '\PowerShell\7\global_MachineAndNodeSettings.ps1') -Target "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\profiles\global_MachineAndNodeSettings.ps1"`
    global_ConfigRootKeys.ps1
    `Remove-Item -path (join-path $env:ProgramFiles '\PowerShell\7\global_ConfigRootKeys.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles  '\PowerShell\7\global_ConfigRootKeys.ps1') -Target "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\profiles\global_ConfigRootKeys.ps1"`
    AllUsersAllHostsV7CoreProfile.ps1
    `Remove-Item -path (join-path $env:ProgramFiles '\PowerShell\7\profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path $env:ProgramFiles  '\PowerShell\7\profile.ps1') -Target "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\profiles\AllUsersAllHostsV7CoreProfile.ps1"`
  Symlink the following to user:Powershell:
- `Remove-Item -path (join-path TBD '\PowerShell\profile.ps1') -ErrorAction SilentlyContinue; New-Item -ItemType SymbolicLink -path (join-path TBD '\PowerShell\profile.ps1') -Target "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.PowerShell\profiles\CurrentUserAllHostsV7CoreProfile.ps1"`

  Note: For development computer: Manually Symlink the Building.powershell module. TBD -install it as a package

  Confirm profiles
  `('AllUsersAllHosts','AllUsersCurrentHost','CurrentUserAllHosts','CurrentUserCurrentHost')|%{'profile' + $_ + ' is '+ $profile.$_}`


License keys for
  Avast Premium
  Beyond compare
  ServiceStack
  Rider Ultimate
  FreeVideoEditor VSDC

powershell profiles and links to modules under development

C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Set-PerceivedTypeInRegistryForPreviewPane.ps1

resx Resource Manager
Voiceattack
Steam
jexus manager (iis manager)

1) debug response time issues and network issues
  Visual Studio Code terminal and file editing; characters don't appear quickly in response to keyboard input

  1) Disable Windows Search Service Indexing background task
    Change list of drives indexed to only "start programs"
    Delete and rebuild index
    Disable  windows indexing  service  "Windows Search" manually using services applet

  1) Windows media player
    options - do not save history

  1) Replace Windows Defender with AVAST
      stop Windows Defender Firewall
      stop windows defencder service
      stop MsSense service
      disable MsSense service

1) Inspect Windows Event Logs and remediate

  1) "BITS has encountered an error communicating with an Internet Gateway Device"
    Set the Service by the name of "Background Intelligent Transfer Service" to manual

  1) "The shadow copies of volume C: were aborted because the shadow copy storage could not grow due to a user imposed limit."  Event Id 36 VolSnap
    Disable restore points on all drives ()
      Search settings for "system protection"
      click "create a restore point"
      scan the list of drivee for any with "Protection settings = ON"
      turn it off and delete any existing restore points
    Disable the 'Volume Shadow Copy" service

Setup Autoruns and startups
  avast
  ditto
  dropbox
  nordvpn
  sharex

Link Pushbullet to phone

Setup HP Printer

File Extension helpers

setup the registry to support "preview as perceived type text" for additional file types
Set-PerceivedTypeInRegistryForPreviewPane from module

setup gopro

from C:\Dropbox\whertzing\Visual Studio 2013\Projects\CI\CI\TealeafCommonComputer.ps1
  # Pin the services applet to the taskbar
  Install-ChocolateyPinnedTaskBarItem "$env:windir\system32\services.msc"
  # Pin the event viewer applet to the taskbar
  Install-ChocolateyPinnedTaskBarItem "$env:windir\system32\eventvwr.msc"

  # Use SQLExpress for Server 2012 if possible
  # ALlow  mixedmode authentication
  #-ia '/value1=''some value'' '
  # Enable SQLServerAgent
  choco install MsSqlServer2012Express -ia '/SECURITYMODE=SQL'
	Install-ChocolateyPinnedTaskBarItem "C:\Program Files (x86)\Microsoft SQL Server\110\Tools\Binn\ManagementStudio\Ssms.exe"


C:\Dropbox\whertzing\Visual Studio 2013\Projects\CI\CI\DeveloperComputer.ps1
  # Set file associations for powergui
  #$suffixs = @(,'.ps1','.psm1','.psd1')
  #Install-ChocolateyFileAssociation  $suffixs "${env:programfiles(x86)}\powerGUI\ScriptEditor.exe"

programs to pin:
  perfView
  taskManager
  scheduled tasks
  OneNote
  Outlook
  RDP
  nmap-zenmap
  Fiddler
  postman
  Firefox
  Chrome
  Edge
  Brave
  Explorer
  Notepadplusplus
  VisualStudioCode
  structuredBuildlogViewer
  ILSpy
  Rider
  resXResourceManager
  pwsh
  MSSMS
  Voiceattack
  Everything

  Setup the PSGallery as trusted
  `Register-PSRepository -Default -Verbose`
  `get-psrepository` validate that PSGallery appears
  `Set-PSRepository -Name PSGallery -InstallationPolicy Trusted`

  

  remove the default version of Pester that comes with windows
  ```Powershell
  $module = "C:\Program Files\WindowsPowerShell\Modules\Pester"
	takeown /F $module /A /R
	icacls $module /reset
	icacls $module /grant "*S-1-5-32-544:F" /inheritance:d /T
	Remove-Item -Path $module -Recurse -Force -Confirm:$false
   ```

   Install Pester for PS V7
   `Install-Module pester

   Fix Pester installation and or path variable for PS V5 and PS V7

   Setup Git
   in file ~/.gitconfig
      [filter "lfs"]
        smudge = git-lfs smudge -- %f
        process = git-lfs filter-process
        required = true
        clean = git-lfs clean -- %f
      [user]
        name = Bill Hertzing
        email = bill.hertzing@gmail.com
      [diff]
        tool = bc3
      [difftool]
        prompt = false
      [merge]
        tool = bc3
      [mergetool]
        prompt = false
      [difftool "bc3"]
        path = "C:/Program Files/Beyond Compare 4/bcomp.exe"
      [mergetool "bc3"]
        path = "C:/Program Files/Beyond Compare 4/bcomp.exe"
      [mergetool "bc3"]
        trustExitCode = true
      [alias]
        mydiff = difftool --dir-diff --tool=bc3 --no-prompt
        bcreview = "!f() { local SHA=${1:-HEAD}; local BRANCH=${2:-master}; if [ $SHA == $BRANCH ]; then SHA=HEAD; fi; git difftool -y -t bc $BRANCH...$SHA; }; f"
      [core]
        autocrlf = true
        editor = code --wait
      [commit]
        template = GitTemplates/git.commit.template.txt
      [merge "keep-local-changes"]
        name = A custom merge driver which always keeps the local changes
        driver = true

VS Code Extensions
  c#

  gitignore
  gitlens
  git graph
  ResExExpress
  Powershell (from Microsoft)
  PowerShell Pro Tools for Visual Studio Code (from Ironman Software)
  Draw.io Integration
  prettier
  Remove TestExplorerUI if it is installed, instead set the settings testExplorer.useNativeTesting to true
  git user and password for each repository
  PlantUML extension requires the environment variable GRAPHVIZ_DOT= ' c:\program files\graphviz\bin\dot.exe' which is the location where chocolatey installs the local plantuml server
  Markdownlint

  use the command `code --list-extensions --show-versions > "\\UTAT022\FileShare\$($env:COMPUTERNAME)extensions.list.txt"`

VS Code Options:
  testExplorer.useNativeTesting to true
  Copy settings from current (ncat016) vscode. Investigate VSC settings sync to keep them aligned

GoogleDrive
 download and install the [Google Drive for Windows](Tbd)
 Sign In with google account crednetials
 Create a directory GoogleDrive on the drive of your choice (I chose c:/GoogleDrive)
 record in global_MachineAndNodeSettings.ps1 file for all computers, use the following `Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq "Google Drive" } | Select-Object -ExpandProperty 'Name') 'My Drive' `
Join-Path  ([Environment]::GetEnvironmentVariable($global:configRootKeys['GoogleDriveBasePathConfigRootKey'])) 'DatedDropboxCursors.json'

  Chocolatey package List Backup
	 ensure the dropbox location is added
	 ensure the GoogleDrive location is added


# Enable PS-Remoting on the new computer

Enable-PSRemoting

# Add the other computers in the group to trustedhosts for WinRM remote management

Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'ncat041, ncat016, utat01 utat022, ncat-ltjo, ncat-ltb1' # ToDo - add wireless hostnames?

# Add the new computer as a trusted host on other computers in the group

## Setup Jenkins Master 
ToDo: how to copy jobs and nodes
ToDo: how to chnage the jenkins agents to communicate with teh new master
### Chnge Powershell from V5 to V7 on Master and Slaves

`http://utat022:4040/configureTools/`
Jenkins->Configure->Tools->Powershell Installations: Defaultwindows =`C:\Program Files\PowerShell\7\pwsh.exe`

Scheduled Job (within Jenkins) to run the `Get-DropBoxAllFolderCursors-Nightly` job every day. The job imports the eponymous script `Get-DropBoxAllFolderCursors-Nightly.ps1`, then executes the function `Get-DropBoxAllFolderCursors-Nightly`

Scheduled Job (within Jenkins) to run the `Confirm-GitFSCK-Nightly` job every day. The job imports the eponymous script `Confirm-GitFSCK-Nightly.ps1`, then executes the function ``Confirm-GitFSCK-Nightly`

Jenkins reporting of the Validate Tools scripts

Many CI steps need Java. Jenkins itself is Java based, as are the PlantUML steps that generate diagrams from embedded info in .md files, and the step that reads all the C# files nad creates PlantUML diagrams from the source code files. Setting up the new computer, need to ensure the correct Java is installed and running.

Check Java Version. Old computer is running jre1.8.0_291, but jre1.8.0_321 exists as a peer to _291.
 On the new computer, only _321 exists (so far...)


PaackageManagement for powershell

`Register-PackageSource -Name chocolatey -Location http://chocolatey.org/api/v2 -Provider PSModule -Verbose`

[NuGet package manager – Build a PowerShell package repository](https://4sysops.com/archives/nuget-package-manager-build-a-powershell-package-repository/)

[Build and install local Chocolatey packages with PowerShell](https://4sysops.com/archives/build-and-install-local-chocolatey-packages-with-powershell/)

[Understanding Chocolatey NuGet packages](https://4sysops.com/archives/understanding-chocolatey-nuget-packages/)

(https://github.com/psake/PowerShellBuild)

[Build Automation in PowerShell](https://github.com/nightroman/Invoke-Build)

[Catesta is a PowerShell module project generator](https://github.com/techthoughts2/Catesta)


# $Path and $psmodulepath in Powershell V5 (Desktop) and V7 (Core)

https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath?view=powershell-7.2

https://docs.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell?view=powershell-7.2