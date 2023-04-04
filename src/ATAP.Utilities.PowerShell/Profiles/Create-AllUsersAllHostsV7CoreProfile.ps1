<#
.SYNOPSIS
Create a fully expanded profile for a specific hostname, based on the AllUsersAllHostsV7Core_Template file
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
  . 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\public\Join-PathNoResolve.ps1'
  
  [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

  [void]$sb.Append(@'

$global:settings[$global:configRootKeys['DropBoxBasePathConfigRootKey']]         = $DropboxBase
$global:settings[$global:configRootKeys['GoogleDriveBasePathConfigRootKey']]     = 'Dummy' # Join-Path ([System.IO.DriveInfo]::GetDrives() | Where-Object { $_.VolumeLabel -eq 'Google Drive' } | Select-Object -ExpandProperty 'Name') 'My Drive'
$global:settings[$global:configRootKeys['OneDriveBasePathConfigRootKey']]        = 'Dummy' # 'C:/OneDrive/'
# This is the default cloud provider's manifestation
$global:settings[$global:configRootKeys['CloudBasePathConfigRootKey']]           = $generalCloudBase
# varous temporary directories
$global:settings[$global:configRootKeys['FastTempBasePathConfigRootKey']]        = $generalTempBase
$global:settings[$global:configRootKeys['BigTempBasePathConfigRootKey']]         = $generalTempBase
$global:settings[$global:configRootKeys['SecureTempBasePathConfigRootKey']]      = Join-PathNoResolve $generalTempBase 'Insecure'
# Chocolatey settings on this host
$global:settings[$global:configRootKeys['ChocolateyCacheLocationConfigRootKey']] = Join-PathNoResolve $generalTempBase 'ChocolateyCache'
# ansible settings on this host
$global:settings[$global:configRootKeys['ansible_remote_tmpConfigRootKey']]      = Join-PathNoResolve $generalTempBase 'Ansible'

$global:settings[$global:configRootKeys['ansible_become_userConfigRootKey']]     = 'whertzing'

# Where all things Security and Secrets related are stored on the filesystem
$global:settings[$global:configRootKeys['SECURE_CLOUD_BASE_PATHConfigRootKey']]  = Join-PathNoResolve $generalCloudBase  "Security"

  # OpenSSL Environment variables
$global:settings[$global:configRootKeys['OPENSSL_HOMEConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "OpenSSL"'
$global:settings[$global:configRootKeys['OPENSSL_CONFConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["OPENSSL_HOMEConfigRootKey"]] "AUdefault.cnf"'
$global:settings[$global:configRootKeys['RANDFILEConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "OpenSSL" "RandomKeySeed"'


  # Related to Certificate Security
  #  In general, places where the files that are used to create certifictes are found
$global:settings[$global:configRootKeys['SecureCertificatesBasePathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "Certificates"'
$global:settings[$global:configRootKeys['SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SecureCertificatesBasePathConfigRootKey"]] "EncryptionPassPhraseFiles"'
$global:settings[$global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SecureCertificatesBasePathConfigRootKey"]] "EncryptedKeys"'
$global:settings[$global:configRootKeys['SecureCertificatesCertificateRequestsPathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SecureCertificatesBasePathConfigRootKey"]] "CertificateRequests"'
$global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SecureCertificatesBasePathConfigRootKey"]] "Certificates"'
$global:settings[$global:configRootKeys['SecureCertificatesDataEncryptionCertificatesPathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SecureCertificatesCertificatesPathConfigRootKey"]] "DECs"'
  # Use this if special purpose openSSL configuration files are needed
$global:settings[$global:configRootKeys['SecureCertificatesOpenSSLConfigsPathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SecureCertificatesBasePathConfigRootKey"]] "CertificateRequestConfigs"'
  # Use this if obfuscation of file names is desired
$global:settings[$global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']]  = 'CrossReference.txt'

  #  These define where a Certificate Authority (CA) keeps the records of the CSRs it is given, and a copy of each Certificate it creates and sign
  #$global:configRootKeys['SecureCertificatesSigningCertificatesPrivateKeysRelativePathConfigRootKey']]  = "'PrivateKeys'"
  #$global:configRootKeys['SecureCertificatesSigningCertificatesNewCertificatesRelativePathConfigRootKey']]  ="'NewCertificates'"
$global:settings[$global:configRootKeys['SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey']]  = 'CertificateIssuedDB.txt'
  #$global:configRootKeys['SecureCertificatesSigningCertificatesSerialNumberRelativePathConfigRootKey']]  = '"CertificateSerialNumber.txt"'

  # These define the latter portion of certificate-related filename (used as the parameter -BaseFileName)
$global:settings[$global:configRootKeys['SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey']]  = 'CAPassPhraseFile.txt'
$global:settings[$global:configRootKeys['SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey']]  = 'CAEncryptedPrivateKey.pem'
$global:settings[$global:configRootKeys['SecureCertificatesCACertificateBaseFileNameConfigRootKey']]  = 'CACertificate.crt'
$global:settings[$global:configRootKeys['SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey']]  = 'SSLServerPassPhraseFile.txt'
$global:settings[$global:configRootKeys['SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey']]  = 'SSLServerEncryptedPrivateKey.pem'
$global:settings[$global:configRootKeys['SecureCertificatesSSLServerCertificateRequestBaseFileNameConfigRootKey']]  = 'SSLServerCertificateRequest.csr'
$global:settings[$global:configRootKeys['SecureCertificatesSSLServerCertificateBaseFileNameConfigRootKey']]  = 'SSLServerCertificate.crt'
$global:settings[$global:configRootKeys['SecureCertificatesCodeSigningPassPhraseFileBaseFileNameConfigRootKey']]  = 'CodeSigningPassPhraseFile.txt'
$global:settings[$global:configRootKeys['SecureCertificatesCodeSigningEncryptedPrivateKeyBaseFileNameConfigRootKey']]  = 'CodeSigningEncryptedPrivateKey.pem'
$global:settings[$global:configRootKeys['SecureCertificatesCodeSigningCertificateRequestBaseFileNameConfigRootKey']]  = 'CodeSigningCertificateRequest.csr'
$global:settings[$global:configRootKeys['SecureCertificatesCodeSigningCertificateBaseFileNameConfigRootKey']]  = 'CodeSigningCertificate.crt'


  # Related to SecretManagement
  #  In general, places where the files that are used to store Secret Vaults are found
$global:settings[$global:configRootKeys['SecureVaultBasePathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "Vaults"'
  # Secret Vault key files and encrypted passwords fles (passwords to open the vaults)
$global:settings[$global:configRootKeys['SecretVaultKeyFilePathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SecureVaultBasePathConfigRootKey"]] "SecretManagement" "KeyFiles","SecretVaultTestingEncryption.key"'
$global:settings[$global:configRootKeys['SecretVaultEncryptedPasswordFilePathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SecureVaultBasePathConfigRootKey"]] "SecretManagement" "EncryptedPasswordFiles","SecretVaultTestingEncryptedPassword.txt"'
  # $global:configRootKeys['EncryptedMasterPasswordsPathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SecureVaultBasePathConfigRootKey"]] "OMPs.json"'
  # $global:configRootKeys['ATAPUtilitiesMasterPasswordsPathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["EncryptedMasterPasswordsPathConfigRootKey"]] "AUMPs.txt" '#
  # The specific details of the  Secret Vault module in use
$global:settings[$global:configRootKeys['SecretVaultExtensionModuleNameConfigRootKey' ]]  = 'SecretManagement.Keepass'
$global:settings[$global:configRootKeys['SecretVaultNameConfigRootKey' ]]  = 'ThisUsersSecretVault'
$global:settings[$global:configRootKeys['SecretVaultDescriptionConfigRootKey' ]]  = 'Secrets stored in a secure vault'
$global:settings[$global:configRootKeys['SecretVaultKeySizeIntConfigRootKey' ]]  = '32'
$global:settings[$global:configRootKeys['SecretVaultPasswordTimeoutConfigRootKey' ]]  = '300'
$global:settings[$global:configRootKeys['SecretVaultPathToKeePassDBConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:configRootKeys["SecureVaultBasePathConfigRootKey"]] "KeePass" "Local.ATAP.Utilities.kdbx"'

  # Place to keep things for Disaster recovery
  # $global:ConfigRootKeys['DisasterRecoveryPathConfigRootKey']]  = 'Join-PathNoResolve $global:settings[$global:ConfigRootKeys["SECURE_CLOUD_BASE_PATHConfigRootKey"]] "DisasterRecovery"'
  # ToDo: figure out how to handle USB sticks and what if not plugged in
$global:settings[$global:ConfigRootKeys['DisasterRecoveryBackupPathConfigRootKey']]  = 'Join-PathNoResolve "C:" "DisasterRecovery"'



# until Get-CollTravEval handles arrays and hashs, add them manuallay, and don't use indirect
# # Set the global PackageRepositoriesCollection
$global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']] = @{
  $global:configRootKeys['RepositoryNuGetFilesystemDevelopmentPackageNameConfigRootKey']                             = $global:settings[$global:configRootKeys['RepositoryNuGetFilesystemDevelopmentPackagePathConfigRootKey']]
  $global:configRootKeys['RepositoryNuGetFilesystemQualityAssurancePackageNameConfigRootKey']                        = $global:settings[$global:configRootKeys['RepositoryNuGetFilesystemQualityAssurancePackagePathConfigRootKey']]
  $global:configRootKeys['RepositoryNuGetFilesystemProductionPackageNameConfigRootKey']                              = $global:settings[$global:configRootKeys['RepositoryNuGetFilesystemProductionPackagePathConfigRootKey']]
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageNameConfigRootKey']              = $global:settings[$global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageNameConfigRootKey']         = $global:settings[$global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerProductionPackageNameConfigRootKey']               = $global:settings[$global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerProductionPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryNuGetProductionWebServerDevelopmentPackageNameConfigRootKey']                    = $global:settings[$global:configRootKeys['RepositoryNuGetQualityAssuranceWebServerDevelopmentPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryNuGetProductionWebServerQualityAssurancePackageNameConfigRootKey']               = $global:settings[$global:configRootKeys['RepositoryNuGetProductionWebServerQualityAssurancePackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryNuGetProductionWebServerProductionPackageNameConfigRootKey']                     = $global:settings[$global:configRootKeys['RepositoryNuGetProductionWebServerProductionPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryPowershellGetFilesystemDevelopmentPackageNameConfigRootKey']                     = $global:settings[$global:configRootKeys['RepositoryPowershellGetFilesystemDevelopmentPackagePathConfigRootKey']]
  $global:configRootKeys['RepositoryPowershellGetFilesystemQualityAssurancePackageNameConfigRootKey']                = $global:settings[$global:configRootKeys['RepositoryPowershellGetFilesystemQualityAssurancePackagePathConfigRootKey']]
  $global:configRootKeys['RepositoryPowershellGetFilesystemProductionPackageNameConfigRootKey']                      = $global:settings[$global:configRootKeys['RepositoryPowershellGetFilesystemProductionPackagePathConfigRootKey']]
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageNameConfigRootKey']      = $global:settings[$global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerDevelopmentPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageNameConfigRootKey'] = $global:settings[$global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerProductionPackageNameConfigRootKey']       = $global:settings[$global:configRootKeys['RepositoryPowershellGetQualityAssuranceWebServerProductionPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerDevelopmentPackageNameConfigRootKey']            = $global:settings[$global:configRootKeys['RepositoryPowershellGetProductionWebServerDevelopmentPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerQualityAssurancePackageNameConfigRootKey']       = $global:settings[$global:configRootKeys['RepositoryPowershellGetProductionWebServerQualityAssurancePackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryPowershellGetProductionWebServerProductionPackageNameConfigRootKey']             = $global:settings[$global:configRootKeys['RepositoryPowershellGetProductionWebServerProductionPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryChocolateyFilesystemDevelopmentPackageNameConfigRootKey']                        = $global:settings[$global:configRootKeys['RepositoryChocolateyFilesystemDevelopmentPackagePathConfigRootKey']]
  $global:configRootKeys['RepositoryChocolateyFilesystemQualityAssurancePackageNameConfigRootKey']                   = $global:settings[$global:configRootKeys['RepositoryChocolateyFilesystemQualityAssurancePackagePathConfigRootKey']]
  $global:configRootKeys['RepositoryChocolateyFilesystemProductionPackageNameConfigRootKey']                         = $global:settings[$global:configRootKeys['RepositoryChocolateyFilesystemProductionPackagePathConfigRootKey']]
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageNameConfigRootKey']         = $global:settings[$global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerDevelopmentPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageNameConfigRootKey']    = $global:settings[$global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerQualityAssurancePackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerProductionPackageNameConfigRootKey']          = $global:settings[$global:configRootKeys['RepositoryChocolateyQualityAssuranceWebServerProductionPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryChocolateyProductionWebServerDevelopmentPackageNameConfigRootKey']               = $global:settings[$global:configRootKeys['RepositoryChocolateyProductionWebServerDevelopmentPackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryChocolateyProductionWebServerQualityAssurancePackageNameConfigRootKey']          = $global:settings[$global:configRootKeys['RepositoryChocolateyProductionWebServerQualityAssurancePackageURIConfigRootKey']]
  $global:configRootKeys['RepositoryChocolateyProductionWebServerProductionPackageNameConfigRootKey']                = $global:settings[$global:configRootKeys['RepositoryChocolateyProductionWebServerProductionPackageURIConfigRootKey']]
}

# ToDo: Fix this temporary thingy
$global:settings[$global:configRootKeys['JenkinsAgentServiceAccountConfigRootKey']] = 'JenkinsAgentSrvAcct'
$global:settings[$global:configRootKeys['JenkinsControllerServiceAccountConfigRootKey']] = 'JenkinsContrlSrvAcct'


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

function Add-SecretStoreVault {
  [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'BuiltIn')]
  param (
    # a Name for the vault
    [string] $Name
    # a Description for the vault
    , [string] $Description
    # The SecretManagement vault extension for the vault
    , [ValidateScript({ Get-InstalledModule -Name $_ })]
    [string] $ExtensionVaultModuleName
    , [Parameter(ParameterSetName = 'KeePass')]
    [ValidateScript({ Test-Path $_ })]
    [string] $PathToKeePassDB
    # a Subject for the DataEncryptionCertificateRequest
    , [string] $Subject
    # a SAN for the DataEncryptionCertificateRequest
    , [string] $SubjectAlternativeName
    # a template for the DataEncryptionCertificateRequest
    , [string] $DataEncryptionCertificateRequestConfigPath
    # A secure place for creating the DataEncryptionCertificateRequest and the DataEncryptionCertificate
    , [ValidateScript({ Test-Path $_ })]
    [string] $SecureTempBasePath
    , [string] $DataEncryptionCertificateRequestFilenameTemplate
    , [string] $DataEncryptionCertificateFilenameTemplate
    # Todo: CertificateValidityPeriodUnits, CertificateValidityPeriod
    # A place to persist the encryption key
    , [string] $KeyFilePath
    # Number of bytes in the key
    , [ValidateSet(16, 24, 32)]
    [int16] $KeySizeInt
    # A place to persist the MasterKey for this specific vault
    , [string] $EncryptedPasswordFilePath
    # a Secure-String password for the vault
    , [SecureString] $PasswordSecureString
    # a password timeout for the vault in seconds
    , [int32] $PasswordTimeout
    # Force the creation of the DEC certificate if one exists, overwrite the KeyFilePath if one exists
    , [switch] $Force
  )
  Write-PSFMessage -Level Debug -Message 'Starting Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

  $originalPSBoundParameters = $PSBoundParameters

  # Does a SecretVault by this name already exist
  if ((Get-SecretVault).Name -eq $Name) {
    #ToDo: if -Force, Add -confirm for this operation instead of always throwing
    #Log('Error',"A SecretVault by this name already exists, remove it and retry this operation: $Name")
    Throw "A SecretVault by this name already exists, remove it and retry this operation: $Name"
  }

  # This function strings together three operations. The function's parameters are used by different operations
  #   We create a subset of the PSBoundParameters, and pass just the needed subset to the functions that perform the three operations

  # Construct a new DataEncryptionCertificateRequest file on disk
  $dataEncryptionCertificateRequestPath = Join-Path $SecureTempBasePath ($DataEncryptionCertificateRequestFilenameTemplate -f $Name)
  Write-PSFMessage -Level Debug -Message ("dataEncryptionCertificateRequestPath = $dataEncryptionCertificateRequestPath")

  $subsetPSBoundParameters = @{}
  ('Subject', 'SubjectAlternativeName', 'DataEncryptionCertificateRequestConfigPath', 'Force') | ForEach-Object { $subsetPSBoundParameters[$_] = $originalPSBoundParameters[$_] }
  New-DataEncryptionCertificateRequest -DataEncryptionCertificateRequestPath $dataEncryptionCertificateRequestPath @subsetPSBoundParameters # Pass this function's parameters to the called function
  # Construct the $dataEncryptionCertificatePath
  $dataEncryptionCertificatePath = Join-Path $SecureTempBasePath ($DataEncryptionCertificateFilenameTemplate -f $Name)
  # Install the -dataEncryptionCertificate for this user on this machine, creating the $dataEncryptionCertificatePath file
  $DataEncryptionCertificateInstallationResults = $null
  $subsetPSBoundParameters.Clear()
  ('Force') | ForEach-Object { $subsetPSBoundParameters[$_] = $originalPSBoundParameters[$_] }
  if ($PSCmdlet.ShouldProcess($null, "Install-DataEncryptionCertificate -dataEncryptionCertificateRequestPath $dataEncryptionCertificateRequestPath -dataEncryptionCertificatePath $dataEncryptionCertificatePath @subsetPSBoundParameters")) {
    try {
      $DataEncryptionCertificateInstallationResults = Install-DataEncryptionCertificate -DataEncryptionCertificateRequestPath $DataEncryptionCertificateRequestPath -dataEncryptionCertificatePath $dataEncryptionCertificatePath @subsetPSBoundParameters # Pass this function's parameters to the called function
    }
    catch { # if an exception ocurrs
      # handle the exception
      $where = $PSItem.InvocationInfo.PositionMessage
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      #Log('Error',"Install-DataEncryptionCertificate failed with $FailedItem : $ErrorMessage at `n $where.")
      Throw "Install-DataEncryptionCertificate failed with $FailedItem : $ErrorMessage at `n $where."
    }
  }
  # Get the thumbprint of the certificate just installed : gci cert: -r  -DocumentEncryptionCert

  # CertReq modifies the Subject, replaceing a ';' with a ', '
  # ToDo: make this a function so it can be easily modified and updated if the behaviour of CertReq changes
  $modSubject = $Subject -replace ';', ', '

  # ToDo: ponder the possibility that there may be more than one data encryption certificate with the same Subject and SubjectAlternativeName
  $thumbprint = (Get-ChildItem -Path 'cert:/Current*/my/*' -Recurse -DocumentEncryptionCert | Where-Object { $_.Subject -match "^$modSubject$" }).Thumbprint
  Write-PSFMessage -Level Debug -Message ("thumbprint = $thumbprint")

  # Encrypt the Password
  if ($PSCmdlet.ShouldProcess($null, 'Encrypt the Password')) {
    # ToDo: wrap in a try/catch block
    $encryptedPassword = ConvertFrom-SecureString -SecureString $PasswordSecureString -AsPlainText | Protect-CmsMessage -To $Thumbprint
    Write-PSFMessage -Level Debug -Message ("encryptedPassword = $encryptedPassword")
  }

  # write the encrypted password to the $EncryptedPasswordFilePath
  $EncryptionKeyBytes = New-Object Byte[] $KeySizeInt
  [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptionKeyBytes)
  # ToDo: Add whatif
  #ToDo: Convert to a securestring before writing to the file
  $EncryptionKeyBytes | Out-File -FilePath $KeyFilePath

  # ToDo import KeyFilePath contents as a secure key
  $EncryptionKeyData = Get-Content $KeyFilePath
  # ToDo: Add whatif
  # ToDo change -key to -securekey
  $PasswordSecureString | ConvertFrom-SecureString -Key $EncryptionKeyData | Out-File -FilePath $EncryptedPasswordFilePath

  #####
  # $PasswordSecureString = ConvertTo-SecureString -String '2345' -AsPlainText -Force
  #####
  # Create the SecretVault using a SecretStore extension vault, and configre it, in one call
  # Use different commands based on parameterset
  $command = $null
  Write-PSFMessage -Level Debug -Message "ParameterSetName = $($PSCmdlet.ParameterSetName)"

  switch ($PSCmdlet.ParameterSetName) {
    BuiltIn {
      $command = "Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters @{Description = ""$Description""; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }"
    }
    KeePass {
      $command = "Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters @{Description = ""$Description""; UseMasterPassword = ""$false""; Path = ""$PathToKeePassDB"" }"
    }
  }
  Write-PSFMessage -Level Debug -Message "command = $command"
  if ($PSCmdlet.ShouldProcess($null, "Register-SecretVault -ModuleName $ExtensionVaultModuleName -VaultParameters @{Authentication='Password';Interaction='None';Password='PasswordSecureStringNotshown';PasswordTimeout=$PasswordTimeout} @subsetPSBoundParameters")) {
    try {
      # ToDo: figure out how to pass the UseMasterPassword switch paramter in a $VaultParamter's hash when run as $command via Invoke-Expression
      #Invoke-Expression $command
      switch ($PSCmdlet.ParameterSetName) {
        BuiltIn {
          Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters @{Description = $Description; Authentication = 'Password'; Interaction = 'None'; Password = $PasswordSecureString; PasswordTimeout = $PasswordTimeout }
        }
        KeePass {
          Register-SecretVault -Name $name -ModuleName $ExtensionVaultModuleName -VaultParameters @{Description = $Description; UseMasterPassword = $true; Path = $PathToKeePassDB }
        }
      }
    }
    catch { # if an exception ocurrs
      # handle the exception
      $where = $PSItem.InvocationInfo.PositionMessage
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      #Log('Error',"Register-SecretVault failed with $FailedItem : $ErrorMessage at `n $where.")
      Throw "Register-SecretVault failed with $FailedItem : $ErrorMessage at `n $where."
    }
  }

  $SecretManagementExtensionVaultInfo = @{Name = $Name; EncryptedPassword = $encryptedPassword; Timeout = $PasswordTimeout; Thumbprint = $Thumbprint; Certificate = $dataEncryptionCertificatePath; CertificateValidityPeriod = ''; CertificateValidityPeriodUnits = '' }

  # Unlock the newly created SecretStore vault
  if ($PSCmdlet.ShouldProcess($null, "Unlock-UsersSecretStore -Name $Name -Dictionary $(Write-HashIndented $SecretManagementExtensionVaultInfo 2 2)")) {
    try {
      Unlock-UsersSecretStore -Name $Name -Dictionary $SecretManagementExtensionVaultInfo
    }
    catch { # if an exception ocurrs
      # handle the exception
      $where = $PSItem.InvocationInfo.PositionMessage
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      #Log('Error',"Unlock-UsersSecretStore failed with $FailedItem : $ErrorMessage at `n $where.")
      Throw "Unlock-UsersSecretStore Threw an exception with $FailedItem : $ErrorMessage at `n $where."
    }
  }

  $SecretVaultTestPassed = $false
  if ($PSCmdlet.ShouldProcess($null, "Test-SecretVault -Name $Name")) {
    try {
      $SecretVaultTestPassed = Test-SecretVault -Name $Name 2>$null # send the Error Output stream to the ol' bitbucket
    }
    catch { # if an exception ocurrs
      # handle the exception
      $where = $PSItem.InvocationInfo.PositionMessage
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      #Log('Error',"Test-SecretVault failed with $FailedItem : $ErrorMessage at `n $where.")
      Throw "Test-SecretVault Threw an exception with $FailedItem : $ErrorMessage at `n $where."
    }
    if (-not $SecretVaultTestPassed) {
      Throw "Test-SecretVault failed with $($error[0])"
    }
  }
  Write-PSFMessage -Level Debug -Message 'Leaving Function %FunctionName% in module %ModuleName%' -Tag 'Trace'

  # Return the SecretManagementExtensionVaultInfo structure
  $SecretManagementExtensionVaultInfo
}

# [Display Subject Alternative Names of a Certificate with PowerShell](https://social.technet.microsoft.com/wiki/contents/articles/1447.display-subject-alternative-names-of-a-certificate-with-powershell.aspx)
# ((ls cert:/Current*/my/* | ?{$_.EnhancedKeyUsageList.FriendlyName -eq 'Document Encryption'}).extensions | Where-Object {$_.Oid.FriendlyName -match "subject alternative name"}).Format(1)

<#
 Get-UsersSecretStoreVault -Name 'MyPersonalSecrets' `
  -Description 'Secrets For a specific user on a specific computer' `
  -ExtensionVaultModuleName 'SecretManagement.Keepass' `
  -PathToKeePassDB 'C:\KeePass\Local.ATAP.Utilities.Secrets.kdbx' `
  -Subject 'CN=Bill.hertzing@ATAPUtilities.org;OU=Supreme;O=ATAPUtilities' `
  -SubjectAlternativeName 'Email=Bill.hertzing@gmail.com' `
  -PasswordSecureString $( '1234'| ConvertTo-SecureString -AsPlainText -Force) `
  -PasswordTimeout 900 `
  -KeyFilePath 'C:/dropbox/whertzing/encryption.key'`
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



