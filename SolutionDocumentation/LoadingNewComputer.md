
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

debug response time issues nad netowkr issues
  Visual Studio Code terminal and file editing; characters don't appear quickly in response to jekeyboard input

  1) Disable Windows Search Service Inndexing background task
    Chnage list of drives indexed to only "start programs"
      Delete and rebuild index
    Disable  windows indexing  service  "Windows Search" manually using services applet

    


Setup Autoruns and startups
  avast
  ditto
  dropbox
  nordvpn
  sharex

Link Pushbullet to phone

Setup HP Printer

File Extension helpers

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

VS Code Extensions
  gitlens
  git graph
  ResExExpress
