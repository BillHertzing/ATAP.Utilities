<#
.SYNOPSIS
Create a fully expanded profile for a specific hostname, based on the AllUsersAllHostsV7Core_Template file.
The Ansible WindosHosts group playbook uses this file to create/update the machine profile for each host
.DESCRIPTION
This is the common machine profile. It provides global and environment variables that hold the machine specific settings
This is for All Users, All Hosts, Powershell Core V7
Details in [powerShell ReadMe](src\ATAP.Utilities.Powershell\Documentation\ReadMe.md)

.INPUTS
$hostname
.OUTPUTS
AllUSersAllHostsV7CoreProifile_$hostname.ps1
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

function Create-AllUsersAllHostsV7CoreProfile {
  param(
    [string] $hostname
  )
  switch -regex ($hostname) {
    '^(?:utat01|utat022|ncat016|ncat041)$' {
      $generalTempBase = 'C:\Temp'
      $generalProgramFilesBase = 'C:\Program Files'
      $DropboxBase = 'C:\DropBox'
      $generalCloudBase = $DropboxBase
    }
    '^(?:ncat-ltb1|ncat-ltjo)$' {
      $generalTempBase = 'D:\Temp'
      $generalProgramFilesBase = 'C:\Program Files'
      $DropboxBase = 'D:\DropBox'
      $generalCloudBase = $DropboxBase
    }

  }

  # Until ATAP.Utilities.Powershell is a module in the $PSModulePath, import the function
  . $(Join-Path -Path $([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities', 'src', 'ATAP.Utilities.Powershell', 'public', 'Join-PathNoResolve.ps1'))


  # Dot source the list of configuration keys
# Configuration root key .ps1 files should be a peer of the machine profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. "$PSScriptRoot/global_ConfigRootKeys.ps1"
# Print the global:ConfigRootKeys if Debug
Write-PSFMessage -Level Debug -Message ('global:configRootKeys:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:configRootKeys ($indent + $indentIncrement) $indentIncrement) + '}' )

# [Ansible: Understanding variable precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)

# Dot source the Security and Secrets settings
# Security and Secrets setting .ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. "$PSScriptRoot/global_SecurityAndSecretsSettings.ps1"
# Print the global:SecurityAndSecretsSettings if Debug
Write-PSFMessage -Level Debug -Message ('global:SecurityAndSecretsSettings:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:SecurityAndSecretsSettings ($indent + $indentIncrement) $indentIncrement) + '}')

# Dot source the common machine settings
# MachineAndNodeSettings.ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. $PSScriptRoot/global_MachineAndNodeSettings.ps1
# Print the global:MachineAndNodeSettings if Debug
Write-PSFMessage -Level Debug -Message ('global:MachineAndNodeSettings:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:MachineAndNodeSettings ($indent + $indentIncrement) $indentIncrement) + '}')

# Dot source the PerGroupSettings
# PerGroupSettings.ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. $PSScriptRoot/global_PerGroupSettings.ps1
# Print the global:PerGroupSettings FOR THIS HOST if Debug
Write-PSFMessage -Level Debug -Message ('global:global_PerGroupSettings (for ' + $hostname + '):' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:PerGroupSettings ($indent + $indentIncrement) $indentIncrement) + '}')

# Dot source the PerRoleSettings
# PerRoleSettings.ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. $PSScriptRoot/global_PerRoleSettings.ps1
# Print the global:PerRoleSettings FOR THIS HOST if Debug
Write-PSFMessage -Level Debug -Message ('global:global_PerRoleSettings (for ' + $hostname + '):' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:PerRoleSettings ($indent + $indentIncrement) $indentIncrement) + '}')

# Dot source the PerMachineSettings
# PerMachineSettings.ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. $PSScriptRoot/global_PerMachineSettings.ps1
# Print the global:PerMachineSettings FOR THIS HOST if Debug
Write-PSFMessage -Level Debug -Message ('global:PerMachineSettings (for ' + $hostname + '):' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:PerMachineSettings ($indent + $indentIncrement) $indentIncrement) + '}')



  [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
  Get-CollectionTraverseEvaluate -sourceCollections $SourceCollections -destination $DestinationCollection -matchPatternRegex $MatchPatternRegex

  [void]$sb.Append(@'

  ########################################################
# Machine-wide PowerShell Profile
########################################################

# [powerShell ReadMe](src\ATAP.Utilities.Powershell\Documentation\ReadMe.md)
# On most windows machines, $PSHome is at C:/Program Files/Powershell/7

# Set these for debugging the profile
# Don't Print any debug messages to the console
$DebugPreference = 'SilentlyContinue'
# Don't Print any verbose messages to the console
$VerbosePreference = 'SilentlyContinue' # SilentlyContinue Continue

# set ISElevated in the global settings if this script is running elevated
#$global:settings[$global:configRootKeys['IsElevatedConfigRootKey']] = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

'@)
  Set-Content -Path 'C:/Temp/T1.ps1' -Value $sb.ToString()
}

########################################################
# Create the Machine-wide PowerShell Profile
########################################################

# [powerShell ReadMe](src\ATAP.Utilities.Powershell\Documentation\ReadMe.md)
# On most windows machines, $PSHome is at C:/Program Files/Powershell/7

# Set these for debugging the profile
# Don't Print any debug messages to the console
$DebugPreference = 'SilentlyContinue'
# Don't Print any verbose messages to the console
$VerbosePreference = 'SilentlyContinue' # SilentlyContinue Continue

########################################################
# Locally defined functions
########################################################

#region Functions needed by the machine profile, must be defined in the profile, or dot-sourced
# ToDo: move to a fileio package, improve error and OperatingSystem handling
function Join-PathNoResolve {
  param(
    [ValidateNotNullorEmpty()][string] $Path
    , [ValidateNotNullorEmpty()][string] $ChildPath
    , [string[]] $AdditionalPaths
    , [char] $DirectorySeparatorChar = [IO.Path]::DirectorySeparatorChar
  )
  $result = ''
  $numCharacters = $(Measure-Object -InputObject $Path -Character).Characters
  if ($numCharacters -eq 1) {
    # if Path has just 1 character, use Join-Path
    $result = Join-Path $Path $ChildPath $AdditionalPaths
  }
  elseif ($Path.Substring(1, 1) -ne ':') {
    # if Path doesn't start with a Drive letter, then use Join-Path
    $result = Join-Path $Path $ChildPath $AdditionalPaths
  }
  else {
    # Path starts with a drive letter (because it has ':' as second character) so we can't use join-path for the $Path portion, have to emulate it's behaviour
    # The $DirectorySeparatorChar to use depends on the parameter
    if ($Path.Substring($numCharacters - 1, 1) -eq $DirectorySeparatorChar) {
      # However, we can use join-path for the second and remainder arguments
      $result = "$($Path)$($DirectorySeparatorChar)$(Join-Path $ChildPath $AdditionalPaths)"
      # ToDo: replace $DirectorySeparatorChar used by Join-Path if there is a parameter $DirectorySeparatorChar and it differes from the current OS's DirectorySeparatorChar
    }
    else {
      # second character in $Path is not ':' so we can use join-path
      $result = "$($Path)$(Join-Path $ChildPath $AdditionalPaths)"
    }
  }
  $result
}


function Write-ArrayIndented {
  param ($a, $indent, $indentIncrement)
  $outstr = ' ' * $indent
  $a | ForEach-Object {
    switch ($_) {
      ({ $PSItem -is [system.boolean] }) {
        $outstr += $_
        break
      }
      ({ $PSItem -is [system.string] }) {
        $outstr += $_
        break
      }
      ({ $PSItem -is [system.array] }) {
        $outstr += '(' + [Environment]::NewLine
        $outstr += Write-ArrayIndented $_ ($indent + $indentIncrement) $indentIncrement
        $outstr += ' ' * $indent + ')'
        break
      }
      ({ $PSItem -is [System.Collections.Hashtable] }) {
        $outstr += '{' + [Environment]::NewLine
        $outstr += Write-HashIndented $_ ($indent + $indentIncrement) $indentIncrement
        $outstr += ' ' * $indent + '}'
        break
      }
    }
  }
  $outstr += $a -join [Environment]::NewLine
}

Function Write-HashIndented {
  param($hash
    , [int] $initialIndent = 0
    , [int] $indentIncrement = 2
  )

  $outstr = ''
  $hash.GetEnumerator() | Sort-Object -Property Key | ForEach-Object { $outstr += Write-KVPIndented $_ $initialIndent $indentIncrement }
  $outstr
}

function Write-KVPIndented {
  param ($kvp, $indent, $indentIncrement)
  $outstr = ' ' * $indent + $kvp.Key + ' = '
  switch ($kvp.Value) {
    ({ $PSItem -is [system.boolean] }) {
      $outstr += $kvp.Value
      break
    }
    ({ $PSItem -is [system.string] }) {
      $outstr += $kvp.Value
      break
    }
    ({ $PSItem -is [system.array] }) {
      $outstr += '(' + [Environment]::NewLine
      $outstr += Write-ArrayIndented $kvp.Value ($indent + $indentIncrement) $indentIncrement
      $outstr += ' ' * $indent + ')'
      break
    }
    ({ $PSItem -is [System.Collections.Hashtable] }) {
      $outstr += '{' + [Environment]::NewLine
      $outstr += Write-HashIndented $kvp.Value ($indent + $indentIncrement) $indentIncrement
      $outstr += ' ' * $indent + '}'
      break
    }
  }
  $outstr += [Environment]::NewLine
  $outstr
}

Function Write-EnvironmentVariablesIndented {
  param(
    [int] $initialIndent = 0
    , [int] $indentIncrement = 2
  )
  ('Machine', 'User', 'Process') | ForEach-Object { $scope = $_;
    [System.Environment]::GetEnvironmentVariables($scope) | ForEach-Object { $envVarHashTable = $_;
      $envVarHashTable.Keys | Sort-Object | ForEach-Object { $key = $_
        if ($key -eq 'path') {
          $outstr += ' ' * $initialIndent + $key + ' (' + $scope + ') = ' + [Environment]::NewLine + ' ' * ($initialIndent + $indentIncrement) + `
          $($($($envVarHashTable[$key] -split [IO.Path]::PathSeparator) | Sort-Object) -join $([Environment]::NewLine + ' ' * ($initialIndent + $indentIncrement) ) )
        }
        else {
          $outstr += ' ' * $initialIndent + $key + ' = ' + $envVarHashTable[$key] + '  [' + $scope + ']' + [Environment]::NewLine
        }
      }
    }
  }
  $outstr
}

#endregion Functions needed by the machine profile, must be defined in the profile
##################################################################################

Function ValidateTools {
  # validate dotnet
  # validate dotnet build
  # validate java
  # vallidate PlantUML
  # validate PlantUmlClassDiagramGenerator
  # dotnet tool install --global PlantUmlClassDiagramGenerator --version 1.2.4
}

#region Security Subsystem core functions (to be moved into a seperate ATAP.Utilities module)
##################################################################################

# ToDo: write a script to be run once for each user that will setup SecretManagement
# ToDo: write a script to be run (usually once for each user) that will setup access to specific SecretManagementExtensionVault
# ToDo: write a script to be run on-demand that will revoke access to a specific SecretManagementExtensionVault
# ToDo: write a script to be run once for each SecretManagementExtensionVault to create the vault
# ToDo: put all the SecretManagememnt code into a dedicated ATAP.Utilities module

.  $(Join-Path -Path $([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities', 'src', 'ATAP.Utilities.Security.Powershell', 'public', 'Install-DataEncryptionCertificate.ps1'))


# [Display Subject Alternative Names of a Certificate with PowerShell](https://social.technet.microsoft.com/wiki/contents/articles/1447.display-subject-alternative-names-of-a-certificate-with-powershell.aspx)
# ((ls cert:/Current*/my/* | ?{$_.EnhancedKeyUsageList.FriendlyName -eq 'Document Encryption'}).extensions | Where-Object {$_.Oid.FriendlyName -match "subject alternative name"}).Format(1)

<#
  Open-UsersSecretVault -Name 'MyPersonalSecrets' `
  -Description 'Secrets For a specific user on a specific computer' `
  -SecretVaultModuleName 'SecretManagement.Keepass' `
  -PathToKeePassDB 'C:\KeePass\Local.ATAP.Utilities.Secrets.kdbx' `
  -Subject 'CN=Bill.hertzing@ATAPUtilities.org;OU=Supreme;O=ATAPUtilities' `
  -SubjectAlternativeName 'Email=Bill.hertzing@gmail.com' `
  -PasswordSecureString $( '1234'| ConvertTo-SecureString -AsPlainText -Force) `
  -PasswordTimeout 900 `
  -SecretVaultEncryptionKeyFilePath 'C:/dropbox/whertzing/encryption.key'`
  -KeySizeInt 16
  -EncryptedPasswordFilePath 'C:/dropbox/whertzing/secret.encrypted'`
  -DataEncryptionCertificateRequestConfigPath  'C:\DataEncryptionCertificate.template' `
  -SecureTempBasePath $($global:settings[$global:configRootKeys['SecureTempBasePathConfigRootKey']]) `
  -DataEncryptionCertificateRequestFilenameTemplate '{0}_DataEncryptionCertificateRequest.inf' `
  -DataEncryptionCertificateFilenameTemplate '{0}_DataEncryptionCertificate.cer' `
  -Force -Whatif
#>

#endregion Security Subsystem core functions (to be moved into a seperate ATAP.Utilities module)


# indent and indentincrement used when printing debug and verbose messages
$indent = 0
$indentIncrement = 2

#ToDo: document expected values when run under profile, Module cmdlet/function, script.
Write-PSFMessage -Level Debug -Message ('Starting AllUsersAllHostsV7CoreProfile.ps1')
Write-PSFMessage -Level Debug -Message ("WorkingDirectory = $pwd")
Write-PSFMessage -Level Debug -Message ("PSScriptRoot = $PSScriptRoot")
Write-PSFMessage -Level Debug -Message ('EnvironmentVariablesAtStartOfMachineProfile = ' + $(Write-EnvironmentVariablesIndented 0 2 ))
Write-Verbose ('PATH environment variable from Registry for current session = ' + $(Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name 'Path'))

# For cross-platform compatability, get the hostname from the .Net DNS library
$hostName = ([System.Net.DNS]::GetHostByName($Null)).Hostname
Write-PSFMessage -Level Debug -Message ("hostname = $hostName")
# Set all of the "usual" environment variables to this value, to ensure that all of them exist
[System.Environment]::SetEnvironmentVariable('HOSTNAME', $hostname, 'Process')
[System.Environment]::SetEnvironmentVariable('HOST', $hostname, 'Process')
[System.Environment]::SetEnvironmentVariable('COMPUTERNAME', $hostname, 'Process')

# Define default values of common parameters that may be present in a cmdlet's parameter list
$PSDefaultParameterValues = @{
  '*:Encoding' = 'UTF8'
}
# encoding : New-Object System.Text.UTF8Encoding($false) # UTF8 encoded with or without a ByteOrdermark(BOM) which results in System.Text.UTF8Encoding
# encoding : [System.Text.Encoding]::UTF8 which results in System.Text.UTF8Encoding+UTF8EncodingSealed

# Dot source the list of configuration keys
# Configuration root key .ps1 files should be a peer of the machine profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. "$PSScriptRoot/global_ConfigRootKeys.ps1"
# Print the global:ConfigRootKeys if Debug
Write-PSFMessage -Level Debug -Message ('global:configRootKeys:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:configRootKeys ($indent + $indentIncrement) $indentIncrement) + '}' )

# [Ansible: Understanding variable precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)

# Dot source the Security and Secrets settings
# Security and Secrets setting .ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. "$PSScriptRoot/global_SecurityAndSecretsSettings.ps1"
# Print the global:SecurityAndSecretsSettings if Debug
Write-PSFMessage -Level Debug -Message ('global:SecurityAndSecretsSettings:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:SecurityAndSecretsSettings ($indent + $indentIncrement) $indentIncrement) + '}')

# Dot source the common machine settings
# MachineAndNodeSettings.ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. $PSScriptRoot/global_MachineAndNodeSettings.ps1
# Print the global:MachineAndNodeSettings if Debug
Write-PSFMessage -Level Debug -Message ('global:MachineAndNodeSettings:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:MachineAndNodeSettings ($indent + $indentIncrement) $indentIncrement) + '}')

# Dot source the PerGroupSettings
# PerGroupSettings.ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. $PSScriptRoot/global_PerGroupSettings.ps1
# Print the global:PerGroupSettings FOR THIS HOST if Debug
Write-PSFMessage -Level Debug -Message ('global:global_PerGroupSettings (for ' + $hostname + '):' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:PerGroupSettings ($indent + $indentIncrement) $indentIncrement) + '}')

# Dot source the PerRoleSettings
# PerRoleSettings.ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. $PSScriptRoot/global_PerRoleSettings.ps1
# Print the global:PerRoleSettings FOR THIS HOST if Debug
Write-PSFMessage -Level Debug -Message ('global:global_PerRoleSettings (for ' + $hostname + '):' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:PerRoleSettings ($indent + $indentIncrement) $indentIncrement) + '}')

# Dot source the PerMachineSettings
# PerMachineSettings.ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. $PSScriptRoot/global_PerMachineSettings.ps1
# Print the global:PerMachineSettings FOR THIS HOST if Debug
Write-PSFMessage -Level Debug -Message ('global:PerMachineSettings (for ' + $hostname + '):' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:PerMachineSettings ($indent + $indentIncrement) $indentIncrement) + '}')

# Define a global settings hash
$global:settings = @{}

# 'Group Vars' 'Role Vars' 'Host Vars'
#
# Load the PerGroup, PerRole, and PerMachine settings for this computer into the $global:settings hash, evaluating any dependencies
$SourceCollections = @( $global:PerGroupSettings, $global:PerRoleSettings, $global:PerMachineSettings, $global:SecurityAndSecretsSettings, $global:MachineAndNodeSettings)
$matchPatternRegex = [System.Text.RegularExpressions.Regex]::new( 'global:settings\[\s*(["'']{0,1})(?<Earlier>.*?)\1\s*\]', [System.Text.RegularExpressions.RegexOptions]::Singleline + [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) #   $regexOptions # [regex]::new((?smi)'global:settings\[(?<Earlier>.*?)\]')
# Until ATAP.Utilities package imports are working.... dot source the file
.  $(Join-Path -Path $([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities', 'src', 'ATAP.Utilities.Powershell', 'public', 'Get-CollectionTraverseEvaluate.ps1'))
# From the various source collections create the final global:settings
Get-CollectionTraverseEvaluate -SourceCollections $sourceCollections -destination $global:Settings -matchPatternRegex $matchPatternRegex



# Opt Out of the dotnet telemetry
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', 1, 'Process')



# Load the JenkinsRoleSettings for this machine into the $global:settings
# ($global:MachineAndNodeSettings[$hostname])[$global:configRootKeys['JenkinsNodeRolesConfigRootKey']] | ForEach-Object {
#   $nodeName = $_
#   $global:settings[$nodeName] = @{}
#   ($global:JenkinsRoles)[$nodename] | ForEach-Object {
#     $global:settings[$nodename][$_] = $($global:MachineAndNodeSettings[$hostname][$_])
#   }
# }


# If the computer is behind a proxy, configure the default proxy settings in the machine powershell profile.
# [system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('http://YourProxyHostNameGoesHere:ProxyPortGoesHere')
# [system.net.webrequest]::defaultwebproxy.credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
# [system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true

# location of the local chocolatey server per machine

# The $Env:PSModulePath is process-scoped, and it's initial value is supplied by the Powershell host process/engine.
# Powershell Core Version 7.2.5 supplies C:\Dropbox\whertzing\PowerShell\Modules;C:\Program Files\PowerShell\Modules;c:\program files\powershell\7\Modules; in the initial value (process scoped)

# Installing SQL Server 2019 adds the path ;C:\Program Files (x86)\Microsoft SQL Server\150\Tools\PowerShell\Modules\ to the machine scoped $Env:PSModulePath

# additional $PSModulePath locations depend on the user and the role the user has on the machine, so there are no more machine-specific values. See the individual user profiles for furhter additions to the $ENV:PSModulepath

# This machine is part of the CI/CD DevOps pipeline ecosystem
# The global_MachineAndNodeSettings.ps1 file includes the settings for the CI/CD pipeline portions that this machine can participate in
#  Get settings associated with each role for this machine
# C:\Program Files (x86)\Microsoft SQL Server\150\Tools\PowerShell\Modules\

########################################################
# Function Definitions *global* scope
########################################################


# Set DebugPreference to Continue  to see the $global:settings and Environment variables at the completion of this profile
# Print the $global:settings if Debug
$DebugPreference = 'SilentlyContinue'
Write-PSFMessage -Level Debug -Message ('global:settings:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:settings ($indent + $indentIncrement) $indentIncrement) + '}' + [Environment]::NewLine )
Write-PSFMessage -Level Debug -Message ('Environment variables AllUsersAllHosts are: ' + [Environment]::NewLine + (Write-EnvironmentVariablesIndented ($indent + $indentIncrement) $indentIncrement) + [Environment]::NewLine )
$DebugPreference = 'SilentlyContinue'



