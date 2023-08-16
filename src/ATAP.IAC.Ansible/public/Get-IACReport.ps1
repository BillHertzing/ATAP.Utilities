
# inventory file(s)
$IACAnsibleInventoryProductionPath = ''
$IACAnsibleInventoryNonProductionPath = ''

# current host name
# groups the hosts belongs too
# Basic info on OS

# Information about the Powershell interpreters available


# Path and PSModulePath information

# Powershell profile files available (name and versions)

# All environment variables

# All Services
$allServices = Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services;
$allServicesDetails = @{};
for ($index = 0; $index -lt $allServices.count; $index++) {
  $service = $allServices[$index]
  $path = $service.Name -replace 'HKEY_LOCAL_MACHINE', 'HKLM:'
  $name = $($service.Name -split '\\')[-1]
  $allServicesDetails.Add($name, [PSCustomObject]@{
      Name        = $name
      Start       = Get-ItemProperty -Name 'start' -Path $path
      Description = Get-ItemProperty -Name 'description' -Path $path
      RunAs       = $null # Get-ItemProperty -name 'RunAs' -path $path
      PathToExe   = $null
    }
  )
}


# Hosts file contents
$hostsFileInformation = [PSCustomObject]@{
  Encoding              = $null
  EOL                   = $null
  SizeInBytes           = 0
  LastModifiedTimeStamp = $null
  Contents              = $null
}

# Network Adapters present, MAC and IP addresses (IPV4 and IPV6 (DHCP or fixed addresses), DHCP server DNS servers

# Public and private networks present

# Firewall Rules

# WinRFM information, Service, Listener, and Client. HTTPS certificates, Trusted hosts,

# Information on the WinRM Service

# PackageManagement, NuGet, PowershellGet, and ChocolateyGet, repositories, and sources

# SSH Server and SSH Client. Any user or admin keys lodaed

# Powershell Secrets Management, and Secrets Vaults

# information about a hashicorp vault if present

# information about the organization's Certification Authority, if present

# information about any Certificates that are signed with the organization's Certification Authority

# Windows Features per host or groups to which the host belongs

#  WSL2 Role

#  Virtual Switch Asignment Rules

#  Virtual Ethernet Adapter Information

#    Ansible ibstallation information

# Registry settings per host or groups to which the host belongs

# Powershell Modules per host or groups to which the host belongs

# Chocolatey Packages per host or groups to which the host belongs

# SW, Service Accounts, Services, Registry Settings, configuration setings per role per host or groups to which the host belongs

#    Java Interpreter Role

#    Ruby Interpreter Role

#    Python Interpreter Role

#    Jenkins Controller Role
#     $(Get-ItemProperty -Path $($_.name -replace 'HKEY_LOCAL_MACHINE','HKLM:') -Name 'Description' -ErrorAction SilentlyContinue) -match 'defend'
# };
# $servicesmatching += $allservices | Where-Object {$_.name -match 'mpssvc'};
$results.Add('JenkinsControllerRole', [PSCustomObject]@{
    # ToDo, use LINQ to look at both name and description for a match
    ServiceInfo           = $($allServicesDetails.ContainsKey('JenkinsController') -or $($false)) ? $allServicesDetails['JenkinsController'] : $null
    ServiceAccountInfo    = $null
    RegistrySettings      = $null
    ConfigurationSettings = $null
  })


#    Jenkins Client Role

#      Jenkins Client Service information.
#      Jenkins Client Service User Account information.
#      Jenkins Client Registry Settings.

# Cloud storage locations

#    Dropbox exe location, version, and Configuration

#    Google Drive exe location, version, and Configuration

#    MS OneDrive exe location, version, and Configuration

# MSBuild exe location, version, and configuration.

# GIT exe location, version, and configuration.

# Git commit hooks per repository

# Powershell PSScriptAnalyzer exe location, version, and configuration.

# Powershell Carbon module location and version.

# Local users on a host (SIDs)

# Windows Groups on a host

# Windows groups to which local users belongs (Hash keyed by groups and hash keyed by users)

# Group Policy Objects

# NuGet exe location, version, and configuration.

# location of PKI infrastructure files and direcotries for creating new certificate requests, and creating ceertificates

# location of log files

#    PSFramework Logs

# Invoke-Build location, version.
# - tasks to setup Powershell packaging
# - tasks to setup a Code Signing certificate
