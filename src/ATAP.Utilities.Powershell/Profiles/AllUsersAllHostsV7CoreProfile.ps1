<#
.SYNOPSIS
PowerShell V7 profile template for all users on a machine
.DESCRIPTION
This is the common machine profile. It provides global and environment variables that hold the machine specific settings
This is for All Users, All Hosts, Powershell Core V7

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
ToDo: Need attribution for Console Settings
<Where the ideas came from>
.SCM
<Configuration Management Keywords>
#>


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

########################################################
# Locally defined functions
########################################################

#region Functions needed by the machine profile, must be defined in the profile, or dot-sourced
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

function Write-HashIndented {
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

function Write-EnvironmentVariablesIndented {
  param(
    [int] $initialIndent = 0
    , [int] $indentIncrement = 2
  )
  ('Machine', 'User', 'Process') | ForEach-Object { $scope = $_
    [System.Environment]::GetEnvironmentVariables($scope) | ForEach-Object { $envVarHashTable = $_
      $envVarHashTable.Keys | Sort-Object | ForEach-Object { $key = $_
        if ($key -eq 'path') {
          $outstr += ' ' * $initialIndent + $key + ' (' + $scope + ') = ' + [Environment]::NewLine + ' ' * ($initialIndent + $indentIncrement) + `
          $($($($envVarHashTable[$key] -split [IO.Path]::PathSeparator) | Sort-Object) -join $([Environment]::NewLine + ' ' * ($initialIndent + $indentIncrement) ) ) + [Environment]::NewLine
        } else {
          $outstr += ' ' * $initialIndent + $key + ' = ' + $envVarHashTable[$key] + '  [' + $scope + ']' + [Environment]::NewLine
        }
      }
    }
  }
  $outstr
}

#endregion Functions needed by the machine profile, must be defined in the profile
##################################################################################

function ValidateTools {
  # validate dotnet
  # validate dotnet build
  # validate java
  # vallidate PlantUML
  # validate PlantUmlClassDiagramGenerator
  # dotnet tool install --global PlantUmlClassDiagramGenerator --version 1.2.4
}



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
  '*:Encoding' = 'UTF8' # This will be the default parameter value
  '*:Settings' = { $global:settings } # this will be the default parameter value
}
# encoding : New-Object System.Text.UTF8Encoding($false) # UTF8 encoded with or without a ByteOrdermark(BOM) which results in System.Text.UTF8Encoding
# encoding : [System.Text.Encoding]::UTF8 which results in System.Text.UTF8Encoding+UTF8EncodingSealed

# Decide if this machine profile will use the stable branch or sprint branch for its child functions
$repobasepath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'  # Stable worktree StartSprrintAgent and EndSprintAgent populates these
$repobasepath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items'; # sprint worktree
# Load the list of configuration keys into $global:ConfigRootKeys
# May come from the Release package, from the stable worktree, or from a sprint worktree
# Until the Powershell package is released and installed, get it from the stable worktree
# Load the helper script
$projectpathRel = 'src\ATAP.Utilities.ConfigRootKeys.Powershell'
$cmdletPathRel = 'public\Set-GlobalConfigRootKeys.ps1'
try {
  # This will auto-load and return true if the Package is installed
  if (-not (Get-Command -Name 'Set-GlobalConfigRootKeys' -CommandType Function -ErrorAction SilentlyContinue)) {
    # SprintEndAgent uncomments the following line
    # SprintStartAgent comments the following line
    #$repobasepath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities'
    # sprintstartagent insert a line similar to this, sprintendagent removes this line
    $repobasepath = 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-100-Sprint-0007-work-items'
    $projectpathRel = 'src\ATAP.Utilities.ConfigRootKeys.Powershell'
    $cmdletPathRel = 'public\Set-GlobalConfigRootKeys.ps1'
    . $(Join-Path $repobasepath $projectpathRel $cmdletPathRel)
  }
} catch {
  $errorMessage = "Failed to load required functions. Exception: $($_.Exception.Message)"
  Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $errorMessage
  throw
}
Set-GlobalConfigRootKeys

# [Ansible: Understanding variable precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)

### This starts the area where we load the settings for this host
# Until ATAP.Utilities.Powershell is released as an installed module, dot-source
# Get-HostSettings.ps1 from the active worktree. The cmdlet itself locates the
# IAC HostSettings.ps1 (sprint worktree, stable worktree, or installed module
# Resources) and loads any helpers it needs.
$getHostSettingsPath = Join-Path $repobasepath 'src\ATAP.Utilities.Powershell\public\Get-HostSettings.ps1'
if (-not (Get-Command -Name 'Get-HostSettings' -CommandType Function -ErrorAction SilentlyContinue)) {
  . $getHostSettingsPath
}

$global:settings = Get-HostSettings -hostName $hostName -IACBasePath $repobasepath


# 'Group Vars' 'Role Vars' 'Host Vars'
#
# Load the PerGroup, PerRole, and PerMachine settings for this computer into the $global:settings hash, evaluating any dependencies
# $SourceCollections = @( $global:PerGroupSettings, $global:PerRoleSettings, $global:PerMachineSettings, $global:SecurityAndSecretsSettings, $global:MachineAndNodeSettings)
# $matchPatternRegex = [System.Text.RegularExpressions.Regex]::new( 'global:settings\[\s*(["'']{0,1})(?<Earlier>.*?)\1\s*\]', [System.Text.RegularExpressions.RegexOptions]::Singleline + [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) #   $regexOptions # [regex]::new((?smi)'global:settings\[(?<Earlier>.*?)\]')
# # Until ATAP.Utilities package imports are working.... dot source the file
# .  $(Join-Path -Path $([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'GitHub' -AdditionalChildPath @('ATAP.Utilities', 'src', 'ATAP.Utilities.Powershell', 'public', 'Get-CollectionTraverseEvaluate.ps1'))
# # From the various source collections create the final global:settings
# Get-CollectionTraverseEvaluate -SourceCollections $sourceCollections -destination $global:Settings -matchPatternRegex $matchPatternRegex


# set ISElevated in the global settings if this script is running elevated
$global:settings[$global:configRootKeys['IsElevatedConfigRootKey']] = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

# Opt Out of the dotnet telemetry
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', 1, 'Process')

# Ensure machine-wide dotnet tools (notably nbgv) are resolvable for every
# local account, including service accounts such as SvcBuildmaster that do
# not have a per-user dotnet tool path. The canonical location is
# C:\ProgramData\dotnet\tools (populated by
# `dotnet tool install --tool-path 'C:\ProgramData\dotnet\tools' nbgv`,
# per NewComputerSetup.md section 4.4).
$machineDotnetTools = 'C:\ProgramData\dotnet\tools'
if (Test-Path -LiteralPath $machineDotnetTools) {
  $pathParts = $env:Path -split [IO.Path]::PathSeparator
  if ($pathParts -notcontains $machineDotnetTools) {
    $env:Path = $machineDotnetTools + [IO.Path]::PathSeparator + $env:Path
  }
}

# only set the value of the Environment Environment variable if it has not been set by a calling process
$inheritedEnvironmentVariable = [System.Environment]::GetEnvironmentVariable('Environment')
$inProcessEnvironmentVariable = ''
if ($inheritedEnvironmentVariable) {
  $inProcessEnvironmentVariable = $inheritedEnvironmentVariable
} else {
  $inProcessEnvironmentVariable = 'Production' # default for all machines is Production, can be overwritten on a per-process basis if needed
}
$global:settings[$global:configRootKeys['ENVIRONMENTConfigRootKey']] = $inProcessEnvironmentVariable

# Note on $env:PSModulePAth
# The $Env:PSModulePath is process-scoped, and it's initial value is supplied by the Powershell host process/engine.
# Powershell Core supplies [Environment]::GetFolderPath('MyDocuments')\PowerShell\Modules;C:\Program Files\PowerShell\Modules;c:\program files\powershell\7\Modules; in the initial value (process scoped)
# The engine then loads the contents of the property 'PSModulePath' from the registry Key "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
# To see the value of this registry key/property, run the command
#  $(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -name 'PSModulePath')
# Installing some software on a host may modify this registry key, for example...
# Installing SQL Server 2019 adds the path ;C:\Program Files (x86)\Microsoft SQL Server\150\Tools\PowerShell\Modules\ to the Registry setting for the machine scoped $Env:PSModulePath
# For all ATAP organization hosts, we have made the opinionated decision to include the powershell Desktop modules in the PSModulePath for Powershell Core.
#  The reason? There are just too many cmdlets in the desktop modules that are needed for managing Windows hosts and networks, for these modules to be left out
# additional $PSModulePath locations depend on the user and the role the user has on the machine, so there are no more machine-specific values. See the individual user profiles for further additions to the $ENV:PSModulepath
# Get the current $Env:PSModulePath (should be the values pre-populated by the engine, appended with the "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" PSModuleProperty )
$modifiedPSModulePath = $Env:PSModulePath
# using New-PSSession -ConfigurationName WithProfile  failed with the following error message : Could not load file or assembly 'System.Security.Cryptography, Version=7.0.0.0
# 'System.Security.Cryptography.dll' is in C:\Program Files\PowerShell\7, which is not in the PSModulepath by default, so, add it
# $modifiedPSModulePath += ';C:\Program Files\PowerShell\7'
# Add the Desktop module path to the end of the string
# $modifiedPSModulePath += ';C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
# Set the environment variable to the new value

# In your $PROFILE, reorder PSModulePath
$ordered = @(
  'C:\Program Files\PowerShell\Modules',          # PS7 AllUsers  (25)
  'c:\program files\powershell\7\Modules',         # PS7 built-in  (24)
  'C:\Dropbox\whertzing\PowerShell\Modules',       # your personal (16)
  'C:\Program Files (x86)\Microsoft SQL Server\160\Tools\PowerShell\Modules',  # SQL (1)
  'C:\Program Files\WindowsPowerShell\Modules',    # WPS legacy   (132) - push to end
  'C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'  # WPS system  (120) - push to end
)
$env:PSModulePath = $ordered -join ';'
$Env:PSModulePath = $modifiedPSModulePath


# If the computer is behind a proxy, configure the default proxy settings in the machine powershell profile.
# [system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('http://YourProxyHostNameGoesHere:ProxyPortGoesHere')
# [system.net.webrequest]::defaultwebproxy.credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
# [system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true

# location of the local chocolatey server per machine

# This machine is part of the CI/CD DevOps pipeline ecosystem
# The global_MachineAndNodeSettings.ps1 file includes the settings for the CI/CD pipeline portions that this machine can participate in
#  Get settings associated with each role for this machine
# C:\Program Files (x86)\Microsoft SQL Server\150\Tools\PowerShell\Modules\

########################################################
# Function Definitions *global* scope
########################################################

# TBD - move to powershell utilities
function Set-CredentialFile {
  # Todo cmdlet
  param (
    # ToDo add whatif
    [string] $SharedSecureCredentialDirectory
    , [string] $CredentialFilename = "PowershellCredentials-$env:username-$env:hostname.xml"
    , [switch] $force
  )
  $credentialFilePath = $(Join-Path $SharedSecureCredentialDirectory $CredentialFilename)
  if (-not $(Test-Path -Path $SharedSecureCredentialDirectory -PathType Container)) {
    if ($force) {
      # ToDo: check for ACL permissions to create
      New-Item -Path $SharedSecureCredentialDirectory -ItemType Container > $null
    } else {
      throw "$SharedSecureCredentialDirectory does not exist"
    }
    if ($(Test-Path -Path $credentialFilePath -PathType Leaf)) {
      # if the file already exists, don't overwrite it unless force is tru
      if (-not $force) {
        # ToDo: see if we can create the file, throw permissions error if not
        throw "$credentialFilePath already exists, use -force to modify it"
      }
    }
    $credential = Get-Credential
    # ToDO: wrap in a what-if and a try catch to catch permission problem
    $credential | Export-Clixml -Path $(Join-Path $SharedSecureCredentialDirectory $CredentialFilename)
  }
}

function Get-CredentialFile {
  param (
    [string] $Path
  )
  $credential = Import-Clixml -Path $path
  $credential
}

Write-PSFMessage -Level Debug -Message ('Ending AllUsersAllHostsV7CoreProfile.ps1')

# PSFramework starts a background logging runspace; stop it so direct profile
# invocations do not keep pwsh alive after the profile body has finished.
if (Test-Path -LiteralPath 'Function:\Stop-PSFRunspace') {
  Stop-PSFRunspace -Name 'PSFramework.logging' -ErrorAction SilentlyContinue
}

# Set DebugPreference to Continue  to see the $global:settings and Environment variables at the completion of this profile
# Print the $global:settings if Debug
$DebugPreference = 'SilentlyContinue'
#Write-PSFMessage -Level Debug -Message ('global:settings:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:settings ($indent + $indentIncrement) $indentIncrement) + '}' + [Environment]::NewLine )
#Write-PSFMessage -Level Debug -Message ('Environment variables AllUsersAllHosts are: ' + [Environment]::NewLine + (Write-EnvironmentVariablesIndented ($indent + $indentIncrement) $indentIncrement) + [Environment]::NewLine )
$VerbosePreference = 'SilentlyContinue'


