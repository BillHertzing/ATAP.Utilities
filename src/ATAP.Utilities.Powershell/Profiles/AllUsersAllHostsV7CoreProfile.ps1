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
ToDo: Need attribution for IsElevated = ((whoami /all) -match $'S-1-5-32-544|S-1-16-12288') Magic SId's
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

#region Functions needed by the machine profile, must be defined in the profile
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

Function Write-EnvironmentVariables {
  param(
    [int] $initialIndent = 0
    , [int] $indentIncrement = 2
  )
  $outstr = ''
  Get-ChildItem env: | sort-Object -Property Key | ForEach-Object { $envVar = $_;
    ('Machine', 'User', 'Process') | # 'Machine', 'User', 'Process'
    ForEach-Object { $scope = $_;
      if (([System.Environment]::GetEnvironmentVariable($envVar.key, $scope))) {
        # '{0}:{1} ({2}){3}' -f $envVar.key, $envVar.value, $scope, [Environment]::NewLine
        #$outstr += '{0}:{1} ({2})' -f $envVar.key, $envVar.value, $scope + "`r`n`t"
        if ($envVar.key -eq 'path') {
         $outstr += ' ' * $initialIndent + $envVar.key + ' = ' + [Environment]::NewLine + ' ' * ($initialIndent + $indentIncrement) + `
           $($($envVar.value -split ';') -join $([Environment]::NewLine + ' ' * ($initialIndent + $indentIncrement) ) )`
           + '  [' + $scope + ']' +  [Environment]::NewLine
        } else {
          $outstr += ' ' * $initialIndent + $envVar.key + ' = ' + $envVar.value +'  [' + $scope + ']' +  [Environment]::NewLine

        }
  }}}

  $outstr
}
Function ValidateTools {
  # validate dotnet
  # validate dotnet build
  # validate java
  # vallidate PlantUML
  # validate PlantUmlClassDiagramGenerator
  # dotnet tool install --global PlantUmlClassDiagramGenerator --version 1.2.4
}

#endregion Functions needed by the machine profile, must be defined in the profile
##################################################################################

#ToDo: document expected values when run under profile, Module cmdlet/function, script.
Write-Verbose "Starting $($MyInvocation.Mycommand)"
Write-Verbose ("WorkingDirectory = $pwd")
Write-Verbose ("PSScriptRoot = $PSScriptRoot")
Write-Verbose ("EnvironmentVariablesAtStartOfMachineProfile = " + $(Write-EnvironmentVariables 0 2 ))
Write-Verbose ("Registry Current Session Environment variable path = " + $(Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name "Path"))


$indent = 0
$indentIncrement = 2
# Dot source the list of configuration keys
# Configuration root keys .ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. $PSScriptRoot/global_ConfigRootKeys.ps1

# Print the global:ConfigRootKeys if Debug
Write-Debug ('global:configRootKeys:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:configRootKeys ($indent + $indentIncrement) $indentIncrement) + '}' )

# Dot source the Machine and Node settings
# Machine and Node setting .ps1 files should be a peer of the profile. Its location is determined by the $PSScriptRoot variable, which is the location of the profile when the profile is executing
. $PSScriptRoot/global_MachineAndNodeSettings.ps1

# Print the global:MachineAndNodeSettings if Debug
Write-Debug ('global:MachineAndNodeSettings:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:MachineAndNodeSettings ($indent + $indentIncrement) $indentIncrement) + '}')

# Define a global settings hash, initially populate it with machine-specific information for this machine
$global:settings = @{}

# set ISElevated for the global settings if this is script elevated
$global:settings[$global:configRootKeys['IsElevatedConfigRootKey']] = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

# Load settings common to all machines into $global:settings
($global:MachineAndNodeSettings['AllCommon']).Keys | ForEach-Object {
  $global:settings[$_] = $($global:MachineAndNodeSettings['AllCommon'])[$_]
}

# Load the machine-specific settings into $global:settings
($global:MachineAndNodeSettings[$env:COMPUTERNAME]).Keys | ForEach-Object {
  $global:settings[$_] = $($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$_]
}

# Load the JenkinsRoleSettings for this machine into the $global:settings
($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$global:configRootKeys['JenkinsNodeRolesConfigRootKey']] | ForEach-Object {
  $nodeName = $_
  $global:settings[$nodeName] = @{}
  ($global:JenkinsRoles)[$nodename] | ForEach-Object {
    $global:settings[$nodename][$_] = $($global:MachineAndNodeSettings[$env:COMPUTERNAME][$_])
  }
}

# Opt Out of the dotnet telemetry
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', 1, 'Process')

# If the computer is behind a proxy, configure the default proxy settings in the machine powershell profile.
# [system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy('http://YourProxyHostNameGoesHere:ProxyPortGoesHere')
# [system.net.webrequest]::defaultwebproxy.credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
# [system.net.webrequest]::defaultwebproxy.BypassProxyOnLocal = $true

# location of the local chocolatey server per machine

# Structure of package drop location; File Server Shares (fss) and Web Server URLs
# ToDo: can this all be done with a local nuget server, instead? What about companies where the developers who want to use ATAPUtilities, cannot add a nuget server to their environment. Local Feed on a file: (and UNC) protocol?
$global:Settings[$global:configRootKeys['PackageDropPathsConfigRootKey']] = @{fssdev = '\\fs\pkgsDev'; fssqa = '\\fs\pkgsqa'; fssprd = '\\fs\pkgs'; wsudev = 'http://ws/ngf/dev'; wsuqa = 'http://ws/ngf/qa'; wsuprd = 'http://ws/ngf' }

# Initialize the additionalPSModulePaths with the location where chocolatey installs modules
$additionalPSModulePaths = @($global:Settings[$global:configRootKeys['ChocolateyLibDirConfigRootKey']]);
# extract all the psmodulepath items from the global:Settings
# The following ordered list of module paths come from the installation locations of modules specified for this machine in the the global:Settings

# The $Env:PSModulePath is process-scoped, and it's initial value is supplied by the Powershell host process/engine
# Add the $additionalPSModulePaths.
$desiredPSModulePaths = $additionalPSModulePaths + $Env:PSModulePath
# Set the $Env:PsModulePath to the new value of $desiredPSModulePaths.
[Environment]::SetEnvironmentVariable('PSModulePath', $DesiredPSModulePaths -join ';', 'Process')
# Clean up the $desiredPSModulePaths
# The use of 'Get-PathVariable' function causes the pcsx module to be loaded here
# ToDo: work out pscx for jenkins clinet agents
#$finalPSModulePaths = Get-PathVariable -Name 'PSModulePath' -RemoveEmptyPaths -StripQuotes
# Set the $Env:PsModulePath to the final, clean value of $desiredPSModulePaths.
#[Environment]::SetEnvironmentVariable('PSModulePath', $finalPSModulePaths -join ';', 'Process')


# This machine is part of the CI/CD DevOps pipeline ecosystem
# The global_MachineAndNodeSettings.ps1 file includes the settings for the CI/CD pipeline portions that this machine can participate in
#  Get settings associated with each role for this machine
# C:\Program Files (x86)\Microsoft SQL Server\150\Tools\PowerShell\Modules\

########################################################
# Function Definitions *global* scope
########################################################


# Set DebugPreference to Continue  to see the $global:settings and Environment variables at the completion of this profile
# Print the $global:settings if Debug
Write-Debug ('global:settings:' + ' {' + [Environment]::NewLine + (Write-HashIndented $global:settings ($indent + $indentIncrement) $indentIncrement) + '}' + [Environment]::NewLine )
#$DebugPreference = 'Continue'
Write-Debug ('Environment variables AllUsersAllHosts are: ' + [Environment]::NewLine + (Write-EnvironmentVariables ($indent + $indentIncrement) $indentIncrement)  + [Environment]::NewLine )


