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
          $($($envVarHashTable[$key] -split [IO.Path]::PathSeparator) -join $([Environment]::NewLine + ' ' * ($initialIndent + $indentIncrement) ) )
        }
        else {
          $outstr += ' ' * $initialIndent + $key + ' = ' + $envVarHashTable[$key] + '  [' + $scope + ']' + [Environment]::NewLine
        }

      }
    }
  }
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

#region Security Subsystem core functions (to be moved into a seperate ATAP.Utilities module)
##################################################################################

# ToDo: write a script to be run once for each user that will setup SecretManagement
# ToDo: write a script to be run (usually once for each user) that will setup access to specific SecretManagementExtensionVault
# ToDo: write a script to be run on-demand that will revoke access to a specific SecretManagementExtensionVault
# ToDo: write a script to be run once for each SecretManagementExtensionVault to create the vault
# ToDo: put all the SecretManagememnt code into a dedicated ATAP.Utilities module
# Setup-SecretManagementPerUser
# ToDo: put all the module management powershell functions into a dedicated ATAP.Utilities module
function Install-ModulesPerComputer {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string[]] $modulesToInstall
    , [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]] $ComputerName
    , [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [PSCredential] $RunAs
    , [Parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]] $repositoriesToTrust = @('PSGallery')

  )
  # ToDo: implement CIMSession if ComputerName is not the currnet computer, or if RunAs is not the current user
  # import the SecretManagement and SecretStore modules if they are not yet present
  $modulesToInstall | ForEach-Object { $moduleName = $_
    Write-Verbose "Processing module named : $modulename"
    # Has it already been loaded in machine scope?
    if (-not (Get-Module -Name $moduleName -ListAvailable)) {
      Write-Verbose "Module named : $modulename has NOT been installed"
      # ToDo: wrap in try/catch
      # In what repository does it exist?
      $foundModule = Find-Module $moduleName
      Write-Debug "Module named : $modulename was found in the $($foundModule.Repository) repository"
      # Is that repository trusted?
      $installationPolicy = (Get-PSRepository -Name $foundModule.Repository).InstallationPolicy
      if ( $installationPolicy -eq 'Untrusted') {
        Write-Debug "Repository $($foundModule.Repository) is NOT trusted"
        # Todo: add feature and process flow to allow admin running this script to decide if the Repository should be trusted for this user on this machine
        if ($repositoriesToTrust.Contains($foundModule.Repository)) {
          Write-Debug "Repository $($foundModule.Repository) is IN the repositoriesToTrust array"
          if ($PSCmdlet.ShouldProcess($foundModule.Repository , 'Set-PSRepository -Name <target> -InstallationPolicy Trusted')) {
            Set-PSRepository -Name $foundModule.Repository -InstallationPolicy Trusted
          }
        }
        else {
          Write-Debug "Repository $($foundModule.Repository) is NOT in the repositoriesToTrust array"
        }
      }
      # ToDo: Version checking?
      # The missing module has been found and the repository is trusted
      if ($PSCmdlet.ShouldProcess(@($moduleName), 'Install-Module -Name <target> -Scope AllUsers ')) {
        Install-Module -Name $moduleName -Scope AllUsers
      }
      Write-Debug "Module named : $modulename has been installed"
    }
    else {
      Write-Verbose "Module named : $modulename has already been installed"
    }
  }
}


function New-DataEncryptionCertificateRequest {
  [CmdletBinding(SupportsShouldProcess = $true)]
  # ToDO: add -force switch to overwrite any exisiting DataEncryptionCertificateRequest
  param (
    [string] $TemplatePath
    , [string] $newsubject
    , [string] $newCertificateRequestPath
    , [string] $SubjectAlternativeName
    , [Guid] $newGuid
    , [switch] $Force
  )
  # Validate parameters
  if (-not (Test-Path $TemplatePath)) {
    Throw "The specified TemplatePath does not exist: $TemplatePath"
  }
  # ToDo: validate newsubject and SubjectAlternativeName
  # Does the parent path for the new certificate path exist
  $parentPath = (Split-Path -Path $newCertificateRequestPath -Parent)
  if (-not (Test-Path $parentPath )) {
    if ($force) {
      if ($PSCmdlet.ShouldProcess($parentPath, 'New-Item -ItemType Directory -Force -Path <target>')) {
        # If the parent path for the new certificate path does not exist at all, create it if -Force is true, else fail
        New-Item -ItemType Directory -Force -Path $parentPath >$null
      }
    }
    else {
      Throw "Part(s) of the parent of the newCertificateRequestPath do not exist, use -Force to create them: $parentPath"
    }
  }
  if ($PSCmdlet.ShouldProcess($newCertificateRequestPath, "Create new CertificateRequest <target> from '$DataEncryptionCertificateTemplatePath' using subject '$newsubject'")) {
    ((Get-Content $DataEncryptionCertificateTemplatePath) -replace 'Subject = .*', ('Subject = "' + $newsubject + '"')) -replace '%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}.*', '%szOID_SUBJECT_ALTERNATIVE_NAME% = "{text}' + $SubjectAlternativeName + '"' |
    Set-Content -Path $newCertificateRequestPath # -Encoding [System.Text.Encoding]::UTF8  default value for my powershelll, but localization may affect this
  }
}

function Install-DataEncryptionCertificate {
  [CmdletBinding(SupportsShouldProcess = $true)]
  # ToDo: add -force switch to overwrite any existing dataEncryptionCertificatePath
  param (
    [string] $dataEncryptionCertificateRequestPath
    , [string] $dataEncryptionCertificatePath
    , [switch] $Force
  )
  # ToDo: Figure out how to ensure this command can be run on a list of remote computers and a list of users on each
  # ToDo: parameter validation on each computer and as each user
  # ToDo: validate Certreq.exe is present and executable
  # Validate parameters
  if (-not (Test-Path $dataEncryptionCertificateRequestPath)) {
    Throw "The specified dataEncryptionCertificateRequestPath does not exist: $dataEncryptionCertificateRequestPath"
  }
  if ($PSCmdlet.ShouldProcess($dataEncryptionCertificateRequestPath, 'Create and install a new Data Encryption Certificate (certreq -new <target>) from the Data Encryption Certificate Request <target>')) {
    try {
      CertReq.exe -new $dataEncryptionCertificateRequestPath $dataEncryptionCertificatePath
    }
    catch {
      # ToDo: handle errors
    }
  }
}

# [Display Subject Alternative Names of a Certificate with PowerShell](https://social.technet.microsoft.com/wiki/contents/articles/1447.display-subject-alternative-names-of-a-certificate-with-powershell.aspx)
# ((ls cert:/Current*/my/* | ?{$_.EnhancedKeyUsageList.FriendlyName -eq 'Document Encryption'}).extensions | Where-Object {$_.Oid.FriendlyName -match "subject alternative name"}).Format(1)



function Create-EncryptedMasterPasswordsFile {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [string] $Path
    , [object[]] $SecretManagementExtensionVaults
    , [string] $SecureTempBasePath
    , [string] $DataEncryptionCertificateTemplatePath
    , [string] $DataEncryptionCertificateRequestSecondPart
    , [string] $DataEncryptionCertificateSecondPart
    , [Switch]$Force
  )
  $SMEVs = @{}
  # Validate parameters
  if (-not (Test-Path $SecureTempBasePath)) {
    Throw "The specified SecureTempBasePath does not exist: $SecureTempBasePath"
  }
  $parentPath = (Split-Path -Path $Path -Parent)
  # If the EMBs's parent subdirectory does not exist at all, create it completely
  if ($force) {
    if ($PSCmdlet.ShouldProcess($parentPath, 'New-Item -ItemType Directory -Force -Path <target>')) {
      # If the $parentpath does not exist at all, create it if -Force is true, else fail
      New-Item -ItemType Directory -Force -Path $parentPath >$null
    }
  }
  else {
    Throw "Part(s) of the parent of the path do not exist, use -Force to create them: $parentPath"
  }

  $SecretManagementExtensionVaults | ForEach-Object {
    $vault = $_;
    # ToDo: write/use a function that will try to create a secure temporary file local to the user on
    $newDataEncryptionCertificateRequestPath = Join-Path $SecureTempBasePath $($vault.name + $DataEncryptionCertificateRequestSecondPart)
    # Get a new DataEncryptionCertificateRequest.inf file on disk
    New-DataEncryptionCertificateRequest -TemplatePath $DataEncryptionCertificateTemplatePath -newSubject $_.Subject -newCertificateRequestPath $newDataEncryptionCertificateRequestPath
    # Gconstruct the $dataEncryptionCertificatePath
    $dataEncryptionCertificatePath = Join-Path $SecureTempBasePath $($vault.name + $DataEncryptionCertificateSecondPart)
    if (Test-Path $dataEncryptionCertificatePath) {
      # If a certificate by that name already exists, fail, unless -force is true, then remove the exisitng certificate
      if ($force) {
        if ($PSCmdlet.ShouldProcess($null, "Remove-Item -Path $dataEncryptionCertificatePath")) {
          Remove-Item -Path $dataEncryptionCertificatePath
        }
      }
      else {
        Throw "The Certificate file already exists, use -Force to overwrite it: $dataEncryptionCertificatePath"
      }
    }
    else {
      if ($PSCmdlet.ShouldProcess($null, "Install-DataEncryptionCertificate -dataEncryptionCertificateRequestPath $newDataEncryptionCertificateRequestPath -dataEncryptionCertificatePath $dataEncryptionCertificatePath")) {
        try {
          Install-DataEncryptionCertificate -dataEncryptionCertificateRequestPath $newDataEncryptionCertificateRequestPath -dataEncryptionCertificatePath $dataEncryptionCertificatePath
        } catch { # if an exception ocurrs
          # handle the exception
          $where = $PSItem.InvocationInfo.PositionMessage
          $ErrorMessage = $_.Exception.Message
          $FailedItem = $_.Exception.ItemName
          Throw "Install-DataEncryptionCertificate failed with $FailedItem : $ErrorMessage at `n $where."
        }

        # Todo: add error handling
        Throw 'Install-DataEncryptionCertificate'
      }
    }
  }
  # Encrypt the Subject $($_.Subject)
  $encryptedSubject = $($_.Subject) | Protect-CmsMessage -To $($_.Subject)
  $SMEVInfo = @{Name = $($_.Name); Path = 'PATH?'; Subject = $($_.Subject); EMP = $encryptedSubject }
  $SMEVs[$($_.Name)] = $SMEVInfo
}
$SMEVs | ConvertTo-Json | Set-Content -Path $SecretManagementExtensionVaultEncryptedMasterPasswordsPath

function New-SecretManagementExtensionVault {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [string] $Name

  )
  Register-SecretVault -Name $Name -ModuleName Microsoft.PowerShell.SecretStore -Description 'Secrets for just me'
}


}

#endregion Security Subsystem core functions (to be moved into a seperate ATAP.Utilities module)

#endregion Functions needed by the machine profile, must be defined in the profile
##################################################################################

#ToDo: document expected values when run under profile, Module cmdlet/function, script.
Write-Verbose "Starting $($MyInvocation.Mycommand)"
Write-Verbose ("WorkingDirectory = $pwd")
Write-Verbose ("PSScriptRoot = $PSScriptRoot")
Write-Verbose ('EnvironmentVariablesAtStartOfMachineProfile = ' + $(Write-EnvironmentVariablesIndented 0 2 ))
Write-Verbose ('Registry Current Session Environment variable path = ' + $(Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name 'Path'))


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

# Load the $global:settings with the $global:ToBeExecutedGlobalSettings
$global:ToBeExecutedGlobalSettings.Keys | ForEach-Object {
  # ToDo error hanlding if one fails
  $global:settings[$_] = Invoke-Expression $global:ToBeExecutedGlobalSettings[$_]
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
[Environment]::SetEnvironmentVariable('PSModulePath', $DesiredPSModulePaths -join [IO.Path]::PathSeparator, 'Process')
# Clean up the $desiredPSModulePaths
# The use of 'Get-PathVariable' function causes the pcsx module to be loaded here
# ToDo: work out pscx for jenkins clinet agents
#$finalPSModulePaths = Get-PathVariable -Name 'PSModulePath' -RemoveEmptyPaths -StripQuotes
# Set the $Env:PsModulePath to the final, clean value of $desiredPSModulePaths.
#[Environment]::SetEnvironmentVariable('PSModulePath', $finalPSModulePaths -join [IO.Path]::PathSeparator, 'Process')


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
Write-Debug ('Environment variables AllUsersAllHosts are: ' + [Environment]::NewLine + (Write-EnvironmentVariablesIndented ($indent + $indentIncrement) $indentIncrement) + [Environment]::NewLine )


