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
  $a = ' '*$indent+$message
  Write-Debug $a
}

# Set these for debugging the profile
# Don't Print any debug messages to the console
$DebugPreference = 'Continue'
# Don't Print any verbose messages to the console
$VerbosePreference = 'Continue' # SilentlyContinue Continue

#ToDo: document expected values when run under profile, Module cmdlet/function, script.
Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
Write-Verbose -Message ("WorkingDirectory = $pwd")
Write-Verbose -Message ("PSScriptRoot = $PSScriptRoot")

$indent = 0

# Dot source the list of configuration keys
. ./global_ConfigRootKeys.ps1
if ($DebugPreference -eq 'Continue') {
  Write-DebugIndented $indent "GLOBAL ConfigRootKeys:"
  $indent += 2
  $global:configRootKeys.Keys |  foreach {
    Write-DebugIndented $indent "$_ = $($global:configRootKeys[$_])"
  }
  $indent -= 2
}

# Dot source the Machine and Node settings
. ./global_MachineAndNodeSettings.ps1
if ($DebugPreference -eq 'Continue') {
 Write-DebugIndented $indent "GLOBAL MachineAndNodeSettings:"
  $indent += 2
  $global:MachineAndNodeSettings.Keys |sort |  foreach { $l1Key = $_
    if ($global:MachineAndNodeSettings[$l1Key] -is [System.Collections.IDictionary]) {
      # write iDictionary header
      Write-DebugIndented $indent "$l1Key is IDictionary:"
      $indent += 2
      ($global:MachineAndNodeSettings[$l1Key]).Keys | sort | foreach { $l2Key = $_
        # write nested settings
        Write-DebugIndented $indent "$l1Key.$l2Key = $(($global:MachineAndNodeSettings)[$l1Key])[$l2Key]"
      }
      $indent -= 2
    } else {
      # write simple settings
      Write-DebugIndented $indent "$l1Key = $global:MachineAndNodeSettings[$_]"
    }
  }
  $indent -= 2
}

# Define a global settings hash, populate with machine-specific information for this machine
$global:settings = @{}
$machineSpecificSettings = $global:MachineAndNodeSettings[$env:COMPUTERNAME]
$machineSpecificSettings.Keys | foreach {
  $global:settings[$_] = $machineSpecificSettings[$_]
}

if ($DebugPreference -eq 'Continue') {
  Write-DebugIndented $indent "GLOBAL SETTINGS:"
  $indent += 2
  $global:settings.Keys |sort |  foreach { $l1Key = $_
    if ($global:settings[$l1Key] -is [System.Collections.IDictionary]) {
      # write iDictionary header
      Write-DebugIndented $indent "$l1Key is IDictionary:"
      $indent += 2
      ($global:Settings[$l1Key]).Keys | sort | foreach { $l2Key = $_
    # write nested settings
        Write-DebugIndented $indent "$l1Key.$l2Key = $($($global:Settings[$l1Key].$l2Key)"
      }
      $indent -= 2
    } else {
      # write simple settings
      Write-DebugIndented $indent "$l1Key = $global:settings[$l1Key]"
    }
  }
  $indent -= 2
}

# This machine is part of the CI/CD DevOps pipeline ecosystem
#  Get settings associated with each role for this machine



# Define the list of Jenkins Node roles this machine can support
#  machineId = utat01
$JenkinsNodeRoles = @('WindowsCodeBuildJenkinsNode', 'WindowsDocumentationBuildJenkinsNode')

$global:settings += @{
  dotnetPath = 'C:\Program Files\dotnet\dotnet.exe'
}

$global:settings += @{
  PlantUmlClassDiagramGeneratorPath = 'C:\Users\whertzing\.dotnet\tools\puml-gen.exe'
  javaPath = 'C:\Program Files\AdoptOpenJDK\jre-16.0.1.9-hotspot\bin\java.exe'
  plantUMLJarPath = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
  docfxPath = 'C:\ProgramData\chocolatey\bin\docfx.exe'
}

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
Write-Verbose ('$global:settings are: ' +  [Environment]::NewLine + ($global:settings.Keys | foreach {"$_ = $($global:settings[$_]) `n"} ))
#Write-Verbose ('$global:settings are: ' +  [Environment]::NewLine + (foreach ($kvp in ($global:settings).GetEnumerator()){"{0}:{1}" -f $kvp.name, $kvp.name,[Environment]::NewLine} ))
#Write-Verbose ("Environment variables AllUsersAllHosts are:  " + [Environment]::NewLine + (Get-ChildItem env: |ForEach-Object{"{0}:{1}{2}" -f $_.key, $_.value, [Environment]::NewLine}))
Write-Verbose ("Environment variables AllUsersAllHosts are:  " + [Environment]::NewLine + (Get-ChildItem env: |ForEach-Object{ $envVar=$_;  ('Machine','User','Process') | %{$scope = $_;
if (([System.Environment]::GetEnvironmentVariable($envVar.key, $scope))) {"{0}:{1} ({2})" -f $envVar.key, $envVar.value, $scope}
}}))



