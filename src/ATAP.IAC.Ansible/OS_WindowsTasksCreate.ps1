$tasks =  @'
---
# code: language=ansible
# Tasks to setup a Windows computer / container

- name: setup a sample configuration file on the windows host
  template:
    src: sample.conf.j2
    dest: {{ FastTempBasePathConfigRootKey }}/sample.conf

# prerequisites
# - common tasks for the Operating System of the computer / container, all of which runas a user who is a member of the administrators group
   # - tasks to setup Network adapter properties
   # - tasks to setup Firewall Rules
   # - tasks to setup WinRM
   # - tasks to setup Powershell profile files
   # - tasks to setup PackageManagement, NuGet, PowershellGet, and ChocolateyGet, repositories, and sources
   # - tasks to setup SSH Server
   # - tasks to setup SSH Client
   # - tasks to setup a Powershell Secrets Management
   # - tasks to setup a Powershell Hashicorp vault
   # - tasks to setup / recognize a Certificate Authority
# - common tasks for managing the users of the computer / container
   # - tasks to assign security roles to a user
'@

set-content -path './OS_Windows/Tasks/main.yml' -Value $sample_conf
