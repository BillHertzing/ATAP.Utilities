# This is the baseprofile on every ATAP machine that holds the machine specific settings
# This is for All Users, All Hosts, Powershell Corre V7

########################################################
# Machine-wide PowerShell Profile
########################################################

# [powerShell ReadMe](src\ATAP.Utilities.Powershell\Documentation\ReadMe.md for details)
# On most windows machines, $PSHome is at C:/Program Files/Powershell/7

# Set these for debugging the profile
# Don't Print any debug messages to the console
$DebugPreference = 'SilentlyContinue'
# Don't Print any verbose messages to the console
$VerbosePreference = 'SilentlyContinue' # SilentlyContinue Continue

#ToDo: document expected values when run under profile, Module cmdlet/function, script.
Write-Verbose -Message ("PSScriptRoot = $PSScriptRoot")

# ToDo: Incorporate a set of constant strings for the keys to the settings, and constant default values (always strings?)

# Read in the ./MachineAndNodeSettings.ps1 file
# $mANS = Load()

# Define a global settings hash, populate with machine-specific information
$global:settings = @{
  DropBoxDir = 'C:/DropBox/'
  # OneDriveDir = 'C:\Users\whertzing\OneDrive'  ## Move to personal user profile, or move drive to common location on machine
  FastTempBasePath = 'C:/Temp'
  BigTempBasePath = 'C:/Temp'
}

# This machine is part of the CI/CD DevOps pipeline ecosystem
#  Get this machine's definition of roles

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
#Write-Verbose ('$global:settings are: ' +  [Environment]::NewLine + (foreach ($kvp in ($global:settings).GetEnumerator()){"{0}:{1}" -f $kvp.name, $kvp.name,[Environment]::NewLine} ))
Write-Verbose ("Environment variables are:  " + [Environment]::NewLine + (Get-ChildItem env: |ForEach-Object{"{0}:{1}{2}" -f $_.key, $_.value, [Environment]::NewLine}))
