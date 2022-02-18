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

prrograms to pin:
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
  
  Setup the PSGallery
  `Register-PSRepository -Default -Verbose`
  `get-psrepository`
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
  

VS Code Options:
  Focus on open editors
  Toggle File Autosave (Save File on click-away)
  testExplorer.useNativeTesting to true
  
  Chocolatey package List Backup
	 ensure the dropbox location is added
