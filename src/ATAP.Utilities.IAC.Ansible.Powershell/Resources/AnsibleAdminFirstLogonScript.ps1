<![CDATA[
# Setup for Ansible Communications
# This runs under the ansibleAdmin user (member of administrators) on first logon of ansibleAdmin
# This section of the autounattend.xml file is generated, use the powershell cmdlet TBD to generate it
# string substitution variables
$ansibleTemporaryDirectory = "ansibleTemporaryDirectoryPlaceholder"
$Global:logFilePath = "ansibleLogFilePathPlaceholder"
$hostsdata = "hostsDataPlaceholder"
$trustedChocolateyRepository = "trustedChocolateyRepositoryNamePlaceholder"
# end string substitution variables
# Workaround prior to autounattend.xml generation
$ansibleTemporaryDirectory = "C:\Temp\Ansible"
$Global:logFilePath = "C:\windows\temp\ansibleAdminFirstLogon.log"
$trustedChocolateyRepository = 'https://community.chocolatey.org'
# end Workaround
# ToDo: only continue if the user is ansibleAdmin
# Create a log file for this script
# ToDo: only continue if the user is ansibleAdmin
"user: $env:USERNAME" | Add-Content -Path $Global:logFilePath
"ansibleAdminFirstLogon starting" | Add-Content -Path $Global:logFilePath
# silence progress bars
$Global:ProgressPreference = 'silentlyContinue'
# Create simple Powershell V5 profile for this user
# Create a Powershell V5 subdirectory for the user if it doesn't already exist
New-Item -ItemType Directory -Force -Path "C:\Users\$env:USERNAME\Documents\WindowsPowerShell" | Add-Content -Path $Global:logFilePath
$profiledata = @'
# Empty Powershell V5 profile for current user
'@
$profiledata  | out-file "C:\Users\$env:USERNAME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
"PowerShell V5 profile file created" | Add-Content -Path $Global:logFilePath
# Populate the local hosts file
# $hostsdata = hostsDataPlaceholder
$hostsdata = @'
# Router
192.168.1.1 Nighthawk
# Computers
# UTAT01
192.168.1.10 utat01-wired                           #                       #                # wired
192.168.1.11 utat01-wifi utat01                     # 18:CC:18:C8:FD:E3     # 18CC18C8FDE3   # atap-5g-2 wifi
# NCAT016
192.168.1.16 ncat016-wired-1 ncat016                # 34:97:F6:8B:2D:AB     # 3497F68B2DAB   # wired # Attached to Ethernet adapter vEthernet (Default Switch):
192.168.1.17 ncat016-wired-2                        # 34:97:F6:8B:2D:AC     # 3497F68B2DAC   # wired
192.168.1.18 ncat016-wifi                           # 74:c6:3b:01:a8:d2     # 74c63b01a8d2   # WiFi
# NCAT016 Default Virtual Switch
172.21.64.1  ncat016-VS                             # 00-15-5D-C9-F0-16     # Ethernet adapter vEthernet (Default Switch):
# UTAT022
192.168.1.22 utat022-wired utat022                  # 50:eb:f6:78:80:5a     # 50ebf678805a   # wired #
192.168.1.23 utat022-wifi                           # 00:91:9E:7C:45:F2     # 00919E7C45F2   # wifi   #
'@
$hostsdata  | out-file 'C:\Windows\System32\drivers\etc\hosts'
"hosts file created" | Add-Content -Path $Global:logFilePath
# enable WinRM
# Ensure all public netorks are made private
$publicNetworkNames = Get-NetConnectionProfile -NetworkCategory Public
"Public network names are: ${$publicNetworkNames - join ','}" | Add-Content -Path $Global:logFilePath
Get-NetConnectionProfile -NetworkCategory Public | Set-NetConnectionProfile -NetworkCategory Private
$publicNetworkNames = Get-NetConnectionProfile -NetworkCategory Public
"remaining Public network names are: ${$publicNetworkNames - join ','}" | Add-Content -Path $Global:logFilePath
# run the built-in command to enable PSRemoting (messes with RSMan)
Enable-PSRemoting -Force | Add-Content -Path $Global:logFilePath
"Enable-PSRemoting completed" | Add-Content -Path $Global:logFilePath
# Reconfigure it again to allow Ansible to connect to this Windows host
"starting the configuration of WinRM to allow Ansible to connect to this host" | Add-Content -Path $Global:logFilePath
# watch out for address changes
$url = "https://github.com/ansible/ansible-documentation/raw/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
$file = "C:\Windows\Temp\ConfigureRemotingForAnsible.ps1"
(New-Object -TypeName System.Net.WebClient).DownloadFile($url, $file)
powershell.exe -ExecutionPolicy ByPass -File $file -DisableBasicAuth true | Add-Content -Path $Global:logFilePath
"completed the configuration of WinRM to allow Ansible to connect to this host" | Add-Content -Path $Global:logFilePath
# restart the WinRM service
"starting the restart of WinRM" | Add-Content -Path $Global:logFilePath
Get-Service -Name WinRM | Restart-Service
"completed the restart of WinRM" | Add-Content -Path $Global:logFilePath
# Get details about the WinRM configuration
"winrm get winrm/config/Service produces:" | Add-Content -Path $Global:logFilePath
winrm get winrm/config/Service | Add-Content -Path $Global:logFilePath
"winrm get winrm/config/Winrs produces:" | Add-Content -Path $Global:logFilePath
winrm get winrm/config/Winrs | Add-Content -Path $Global:logFilePath
"winrm get winrm/config/listener produces:" | Add-Content -Path $Global:logFilePath
winrm enumerate winrm/config/listener | Add-Content -Path $Global:logFilePath
# allow diagnostic pings through the Windows Defender Firewall
"starting the steps to allow diagnostic pings through the Windows Defender Firewall" | Add-Content -Path $Global:logFilePath
netsh advfirewall firewall add rule name="ICMPv4 Allow Ping Requests" protocol=icmpv4:8,any dir=in action=allow | Add-Content -Path $Global:logFilePath
netsh advfirewall firewall add rule name="ICMPv6 Allow Ping Requests" protocol=icmpv6:8,any dir=in action=allow | Add-Content -Path $Global:logFilePath
"completed the steps to allow diagnostic pings through the Windows Defender Firewall" | Add-Content -Path $Global:logFilePath
# Ansible requires a temporary directory in order to make an initial connection
"starting the creation of the Ansible temporary directory at $ansibleTemporaryDirectory" | Add-Content -Path $Global:logFilePath
New-Item -ItemType Directory -Force -Path $ansibleTemporaryDirectory | Add-Content -Path $Global:logFilePath
"completed the creation of the Ansible temporary directory at $ansibleTemporaryDirectory" | Add-Content -Path $Global:logFilePath

# for debugging if needed below this line
# # ToDo: specify a repository reachable from this host, and trust it
# # [Set up Chocolatey for Internal/organizational use](https://docs.chocolatey.org/en-us/guides/organizations/organizational-deployment-guide/0)
# # trust the internal/organizational Chocolatey repository
# # see also - [How do I host a private WinGet Repository on an on-premise server?](https://serverfault.com/questions/1098513/how-do-i-host-a-private-winget-repository-on-an-on-premise-server)
# "starting the installation of Chocolatey" | Add-Content -Path $Global:logFilePath
# Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression | Add-Content -Path $Global:logFilePath
# "completed the installation of Chocolatey" | Add-Content -Path $Global:logFilePath
# # # install Powershell Core from the trustedChocolateyRepository
# # "starting Powershell Core installation" | Add-Content -Path $Global:logFilePath
# # choco install powershell-core -y --no-progress| Add-Content -Path $Global:logFilePath
# # "completed Powershell Core installation" | Add-Content -Path $Global:logFilePath
# # # Create simple Powershell Core profile for this user
# # # Create a Powershell Core subdirectory for the user
# # New-Item -ItemType Directory -Force -Path "C:\Users\$env:USERNAME\Documents\PowerShell" | Add-Content -Path $Global:logFilePath
# # $profiledata = @'
# # # Empty Powershell Core profile for current user
# # '@
# # $profiledata  | out-file "C:\Users\$env:USERNAME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
# # "PowerShell Core profile file created" | Add-Content -Path $Global:logFilePath
# # # install .Net from the local repository
# # # install DotNet desktop runtime (latest production version) from the trustedChocolateyRepository
# # choco install dotnet-desktopruntime -y --no-progress | Add-Content -Path $Global:logFilePath
# # "Microsoft.DotNet.DesktopRuntime installed" | Add-Content -Path $Global:logFilePath
# # refreshenv | Add-Content -Path $Global:logFilePath
# # "dotnet info : $(dotnet /v)" | Add-Content -Path $Global:logFilePath
# # install everything file utility tool
# # "starting the installation of everything" | Add-Content -Path $Global:logFilePath
# # choco install everything -y --no-progress| Add-Content -Path $Global:logFilePath
# # "ending the installation of everything" | Add-Content -Path $Global:logFilePath
# # "starting the removal of edge" | Add-Content -Path $Global:logFilePath
# # cmd.exe /c "C:\Windows\Setup\Scripts\edgeremoval.bat" | Add-Content -Path $Global:logFilePath
# # "ending the removal of edge" | Add-Content -Path $Global:logFilePath
# # "starting the installation of google-chrome-x64" | Add-Content -Path $Global:logFilePath
# # choco install google-chrome-x64 -y --no-progress| Add-Content -Path $Global:logFilePath
# # "ending the installation of google-chrome-x64" | Add-Content -Path $Global:logFilePath
# # ToDo: make chrome the default browser
# # "starting the installation of Python3" | Add-Content -Path $Global:logFilePath
# # choco install -y python3 --no-progress| Add-Content -Path $Global:logFilePath
# # # get python3 version
# # "python info: $(python -V)" | Add-Content -Path $Global:logFilePath
# # "completed the installation of Python3" | Add-Content -Path $Global:logFilePath
# # # upgrade pip to the latest
# # "starting the pip upgrade" | Add-Content -Path $Global:logFilePath
# # python -m pip install --upgrade pip | Add-Content -Path $Global:logFilePath
# # "completed the pip upgrade" | Add-Content -Path $Global:logFilePath
"ansibleAdminFirstLogon completed, rebooting" | Add-Content -Path $Global:logFilePath
shutdown /r /t 0
#::]]>
