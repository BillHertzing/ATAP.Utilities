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

Function Write-DebugIndented {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [int] $indent
    , [string] $message
  )
  $a = ' ' * $indent + $message
  Write-Debug $a
}

# Set these for debugging the profile
# Don't Print any debug messages to the console
$DebugPreference = 'SilentlyContinue'
# Don't Print any verbose messages to the console
$VerbosePreference = 'Continue' # SilentlyContinue Continue

#ToDo: document expected values when run under profile, Module cmdlet/function, script.
Write-Verbose "Starting $($MyInvocation.Mycommand)"
Write-Verbose ("WorkingDirectory = $pwd")
Write-Verbose ("PSScriptRoot = $PSScriptRoot")

$indent = 0

# Dot source the list of configuration keys
# Configuration root keys .ps1 files should be a peer of the profile, and is identified as the subdirectory dir where the profile resides
. $PSScriptRoot/global_ConfigRootKeys.ps1

# Print the ConfigRootKeys if Debug
if ($DebugPreference -eq 'Continue') {
  Write-DebugIndented $indent 'GLOBAL ConfigRootKeys:'
  $indent += 2
  $global:configRootKeys.Keys | ForEach-Object {
    Write-DebugIndented $indent "$_ = $($global:configRootKeys[$_])"
  }
  $indent -= 2
}

# Dot source the Machine and Node settings
. $PSScriptRoot/global_MachineAndNodeSettings.ps1
# Print the GLOBAL MachineAndNodeSettings if Debug
if ($DebugPreference -eq 'Continue') {
  Write-DebugIndented $indent 'GLOBAL MachineAndNodeSettings:'
  $indent += 2
  $global:MachineAndNodeSettings.Keys | Sort-Object | ForEach-Object { $l1Key = $_
    # Should be recursive, this only goes one level deep
    if ($global:MachineAndNodeSettings[$l1Key] -is [System.Collections.IDictionary]) {
      # write iDictionary header
      Write-DebugIndented $indent "$l1Key is IDictionary:"
      $indent += 2
      ($global:MachineAndNodeSettings[$l1Key]).Keys | Sort-Object | ForEach-Object { $l2Key = $_
        # write nested settings
        Write-DebugIndented $indent "$l1Key.$l2Key = $(($global:MachineAndNodeSettings)[$l1Key])[$l2Key]"
      }
      $indent -= 2
    }
    else {
      # write simple settings
      Write-DebugIndented $indent "$l1Key = $global:MachineAndNodeSettings[$_]"
    }
  }
  $indent -= 2
}

# Define a global settings hash, initially populate it with machine-specific information for this machine
$global:settings = @{}
# Is this script elevated?
$global:settings[$global:configRootKeys['IsElevatedConfigRootKey']] = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
# Load the machine-specific settings into $global:settings
($global:MachineAndNodeSettings[$env:COMPUTERNAME]).Keys | ForEach-Object {
  $global:settings[$_] = ($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$_]
}
# Load the JenkinsRoleSettings for this machine
($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$global:configRootKeys['JenkinsNodeRolesConfigRootKey']] | ForEach-Object{
  $nodeName = $_
  ($global:JenkinsRoles)[$nodename] | ForEach-Object{
    Write-Verbose "global:settings[$_] =  $($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$_]"
    $global:settings[$_] = ($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$_]
  }
}
# ($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$global:configRootKeys['JenkinsNodeRolesConfigRootKey']] | ForEach-Object{
#   $nodeName = $_
#   ($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$global:configRootKeys['JenkinsNodeRolesConfigRootKey']][$nodename].Keys | ForEach-Object{
#     $global:settings[$_] = ($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$global:configRootKeys['JenkinsNodeRolesConfigRootKey']][$nodename][$_]
#   }
# }

# Print the $global:settings if Debug
if ($DebugPreference -eq 'Continue') {
  Write-DebugIndented $indent '$global:settings :'
  $indent += 2
  $global:settings.Keys | Sort-Object | ForEach-Object { $l1Key = $_
    if ($global:settings[$l1Key] -is [System.Collections.IDictionary]) {
      # write iDictionary header
      Write-DebugIndented $indent "$l1Key is IDictionary:"
      $indent += 2
      ($global:Settings[$l1Key]).Keys | Sort-Object | ForEach-Object { $l2Key = $_
        if ($global:settings[$l1Key][$l2Key] -is [System.Collections.IDictionary]) {
          $indent += 2
          ($global:Settings[$l1Key][$l2Key]).Keys | Sort-Object | ForEach-Object { $l3Key = $_
            # write nested settings
            $str = $global:Settings[$l1Key][$l2Key][$l3Key]
            Write-DebugIndented $indent "$l1Key.$l2Key.$l3Key = $str"
          }
          $indent -= 2
        }
        else {
          # write nested settings
          $str = $global:Settings[$l1Key][$l2Key]
          Write-DebugIndented $indent "$l1Key.$l2Key = $str"
        }
      }
      $indent -= 2
    }
    else {
      # write simple settings
      $str = $global:settings[$l1Key]
      Write-DebugIndented $indent "$l1Key = $str"
    }
  }
  $indent -= 2
}

# Structure of package drop location; File Server Shares (fss) and Web Server URLs
# ToDo: can this all be done with a local nuget server, instead? What about companies where the developers who want to use ATAPUtilities, cannot add a nuget server to their environment. Local Feed on a file: (and UNC) protocol?
$global:Settings[$global:configRootKeys['PackageDropPathsConfigRootKey']] = @{fssdev = '\\fs\pkgsDev'; fssqa = '\\fs\pkgsqa'; fssprd = '\\fs\pkgs'; wsudev = 'http://ws/ngf/dev'; wsuqa = 'http://ws/ngf/qa'; wsuprd = 'http://ws/ngf' }


# The following ordered list of module paths should exist in the PSModulePath (Powershell V7)
$DefaultPSModulePaths = @(
  $global:Settings[$global:configRootKeys['ChocolateyLibDirConfigRootKey']]
  , 'C:\Program Files\PowerShell\7\Modules'
  , 'C:\Program Files\PowerShell\Modules'
  , 'C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules\'
)

# The following ordered list of module paths come from the installation locations of modules installed as part of this nodes roles

# Add all PSModules specified by the machine and node settings.
($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$global:configRootKeys['JenkinsNodeRolesConfigRootKey']].Keys | ForEach-Object{
  $nodeName = $_
  ($global:MachineAndNodeSettings[$env:COMPUTERNAME])[$global:configRootKeys['JenkinsNodeRolesConfigRootKey']][$nodename] | ForEach-Object{
  }
}
"GotHere"

# Requires IsElevated to be true
[Environment]::SetEnvironmentVariable("PSModulePath", $DesiredPSModulePaths -join ';', 'Machine')

# The use of 'Get-PathVariable' function causes the pcsx module to be loaded here
# Add the Chocolatey lib to the PSModulePath Environment variable
Write-Verbose ('Initial PSModulePath profile is: ' + "`r`n`t" + ($(Get-PathVariable -Name 'PSModulePath' -RemoveEmptyPaths -StripQuotes) -join "`r`n`t"))
$Env:PSModulePath = $global:Settings[$global:configRootKeys['ChocolateyLibDirConfigRootKey']] + ';' + $Env:PSModulePath
Write-Verbose ('Final PSModulePath profile is: ' + "`r`n`t" + (($Env:PSModulePath -split ';') -join "`r`n`t"))



# This machine is part of the CI/CD DevOps pipeline ecosystem
# The global_MachineAndNodeSettings.ps1 file includes the settings for the CI/CD pipeline portions that this machine can participate in
#  Get settings associated with each role for this machine
# C:\Program Files (x86)\Microsoft SQL Server\150\Tools\PowerShell\Modules\

########################################################
# Function Definitions *global* scope
########################################################

Function Get-Settings {}

Function ValidateTools {
  # validate dotnet
  # validate dotnet build
  # validate java
  # vallidate PlantUML
  # validate PlantUmlClassDiagramGenerator
  # dotnet tool install --global PlantUmlClassDiagramGenerator --version 1.2.4

}

# Uncomment to see the $global:settings and Environment variables at the completion of this profile
#Write-Verbose ('$global:settings are: ' + [Environment]::NewLine + ($global:settings.Keys | foreach { "$_ = $($global:settings[$_]) `n" } ))
#Write-Verbose ('$global:settings are: ' +  [Environment]::NewLine + (foreach ($kvp in ($global:settings).GetEnumerator()){"{0}:{1}" -f $kvp.name, $kvp.name,[Environment]::NewLine} ))
#Write-Verbose ("Environment variables AllUsersAllHosts are:  " + [Environment]::NewLine + (Get-ChildItem env: |ForEach-Object{"{0}:{1}{2}" -f $_.key, $_.value, [Environment]::NewLine}))
Write-Verbose ('Environment variables AllUsersAllHosts are:  ' + [Environment]::NewLine +
  (Get-ChildItem env: |
    ForEach-Object {$envVar = $_; ('Machine', 'User') |  # , 'Process'
      ForEach-Object{ $scope = $_;
        if (([System.Environment]::GetEnvironmentVariable($envVar.key, $scope))) {
         # '{0}:{1} ({2}){3}' -f $envVar.key, $envVar.value, $scope, [Environment]::NewLine
          '{0}:{1} ({2})' -f $envVar.key, $envVar.value, $scope  + "`r`n`t"
}}}))



