#function rotateCA {
#[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'DefaultParameterSet' )]
#Param(
# $ValidityPeriod = 1
#, $ValidityPeriodUnits = 'year'
#, [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
#[string] $Encoding
#
#)

# Create a PKI infrastructure for a new organization

# Confirm the installation and accessability of OpenSSL executables and the presence of openSSL environment variables

# Confirm/Create the necessary directory structure at a secure cloud-synced location
# All must be evaulated when the Powershell process is started
# SecureCloudRootPath
# SecureCertificatesPath
# SecureCertificatesEncryptionPassPhraseFilesPath
# SecureCertificatesEncryptedKeysPath
# SecureCertificatesOpenSSLConfigsPath
# SecureCertificatesCertificateRequestsPath
# SecureCertificatesCertificatesPath
# SecureCertificates CA PathPattern
# SecureCertificates CA Root PathPattern
# SecureCertificates CA Intermediate PathPattern
# SecureCertificates CodeSigning PathPattern
# SecureCertificates DataEncryption PathPattern
# SecureCertificates SSLServerCertificates PathPattern
# SecureCertificates SSLClientCertificates PathPattern


# Define a DistinguishedNameHash for the Root CA of the organization

# Create a Root CA

# Create an EncryptionPassPhrase file

# Create an EncryptedKey file

# Create a CA Certificate

# Confirm/Create the necessary directory structure for signing certificates with the CA at a secure cloud-synced location


# Create SSL Server Certificate(s) for all computers in the organization's workgroup

# Define a DistinguishedNameHash for the SSL Server Certificate Request for each computer

# Create an EncryptionPassPhrase file

# Create an EncryptedKey file

# Create a SSL Server Certificate Request

# Create a signed SSL Server Certificate

# Copy the signed SSL Server Certificate from the signing certificate's directory structure to the organization's directory structure

# Deploy the Root CA to each computer in the workgroup

# Deploy the appropriate SSL Server certificate to each computer in the organization's workgroup


. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-DistinguishedNameHash.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-DistinguishedNameQualifiedFilePath.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-EncryptionKeyPassPhraseFile.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-EncryptedPrivateKey.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-CACertificate.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-CertificateRequest.ps1'
. 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\New-SignedCertificate.ps1'

# The fields needed to be supplied for the Distinguished Name and SubjectAlternativeName, for a new RootCA
$DNHash = New-Object PSObject -Property @{
  CN               = 'ATAPUtilities.org'
  EmailAddress     = 'SecurityAdminsList@ATAPUtilities.org'
  Country          = 'US'
  StateOrTerritory = ''
  Locality         = ''
  Organization     = 'ATAPUtilities.org'
  OrganizationUnit = ''
  #DNAsFileNameReplacementPattern                = 'CN="{0}",O="{1}",C="{2}"'
  #SANAsParameterReplacementPattern = 'E="{0}"'
  #KeyUseage                                = @('critical', 'cRLSign', 'digitalSignature', 'keyCertSign')
  #ExtendedKeyUseage                        = 'CA:TRUE'
  # ExtendedKeyUseage = @('critical','codeSigning')
} | New-DistinguishedNameHash

# The parameters needed to be supplied for the EncryptionKeyPassPhrasePath and EncryptedPrivateKeyPath
# ToDo: Investigte fast ways to validate the string provided for the ECCurve is supported by openSSL
$ECCurve = 'P-256'
$Encoding = 'UTF8'

# Construct the needed path (Obfuscate if desired)
# $EncryptionKeyPassPhraseCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey']] $global:settings[$global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']]
# $EncryptionKeyPassPhrasePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey']] -CrossReferenceFilePath $EncryptionKeyPassPhraseCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey']]
$EncryptionKeyPassPhrasePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey']] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey']]
New-EncryptionKeyPassPhraseFile -PassPhrasePath $EncryptionKeyPassPhrasePath
# validate the EncryptionKeyPassPhrasePath exists and is non-zero
if (Test-Path -Path $EncryptionKeyPassPhrasePath -PathType Leaf) {
  if (-not (Get-ItemPropertyValue -Path $EncryptionKeyPassPhrasePath -Name 'Length')) {
    throw "New-EncryptionKeyPassPhraseFile created 0-length EncryptionKeyPassPhrase at $EncryptionKeyPassPhrasePath"
  }
}
else {
  throw "New-EncryptionKeyPassPhraseFile failed to create the EncryptionKeyPassPhrase at $EncryptionKeyPassPhrasePath"
}

# Construct the needed path (Obfuscate if desired)
# $EncryptedPrivateKeyCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']] $global:settings[$global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']]
# EncryptedPrivateKeyPath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey']] -CrossReferenceFilePath $EncryptedPrivateKeyCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']]
$EncryptedPrivateKeyPath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey']] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']]
New-EncryptedPrivateKey -ECCurve $ECCurve -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath
# validate the EncryptedPrivateKeyPath exists and is non-zero
if (Test-Path -Path $EncryptedPrivateKeyPath -PathType Leaf) {
  if (-not (Get-ItemPropertyValue -Path $EncryptedPrivateKeyPath -Name 'Length')) {
    throw "New-EncryptedPrivateKey created 0-length EncryptedPrivateKey at $EncryptedPrivateKeyPath"
  }
}
else {
  throw "New-EncryptedPrivateKey failed to create the EncryptedPrivateKey at $EncryptedPrivateKeyPath"
}

# A CA certificate does not need a Certificate Request
# $CertificateRequestConfigPath = {
#   $CertificateRequestCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesCertificateRequestFilesPathConfigRootKey']] $global:settings[$global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']]
#   Join-Path $global:settings[$global:configRootKeys['SecureCertificatesOpenSSLConfigsPathConfigRootKey']] 'CATemplate.cnf'
# }

# The parameters needed to be supplied for the EncryptionKeyPassPhrasePath and EncryptedPrivateKeyPath
$ValidityPeriod = 2
$ValidityPeriodUnits = 'years'

# Construct the needed path (Obfuscate if desired)
# $CrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']] $global:settings[$global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']]
# $CertificatePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCACertificateBaseFileNameConfigRootKey']] -CrossReferenceFilePath $CrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']]
$CertificatePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCACertificateBaseFileNameConfigRootKey']] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']]
# Write-PSFMessage -Level Debug -Message $(Write-HashIndented -initialIndent 0 -indentIncrement 0 -hash $([ordered]@{
#       EncryptionKeyPassPhrasePath = $EncryptionKeyPassPhrasePath
#       EncryptedPrivateKeyPath     = $EncryptedPrivateKeyPath
#       CertificatePath             = $CertificatePath
#     }))
New-CACertificate -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits -CertificatePath $CertificatePath
# ToDO: another ParameterSet for an optional configuration file
#New-CACertificate -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -CertificateRequestConfigPath $CertificateRequestConfigPath -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits -CertificatePath $CertificatePath
if (Test-Path -Path $CertificatePath -PathType Leaf) {
  if (-not (Get-ItemPropertyValue -Path $CertificatePath -Name 'Length')) {
    throw "New-CACertificate created 0-length Certificate at $CertificatePath"
  }
}
else {
  throw "New-CACertificate failed to create the Certificate at $CertificatePath"
}

# Create the directory structure needed for the CA to sign certificates
# This will only fail once and create the named directory
New-Item -Path $global:settings[$global:configRootKeys['SecureCertificatesSigningCertificatesPathConfigRootKey']] -ItemType Directory -Force > $null
# use the CN property value as the subdirectory name
$rootpath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesSigningCertificatesPathConfigRootKey']] $($DNHash.CN + '_RootCA')
New-Item -Path $rootpath -ItemType Directory -Force > $null
#New-Item -Path $(Join-Path $rootpath $global:settings[$global:configRootKeys['SecureCertificatesSigningCertificatesPrivateKeysRelativePathConfigRootKey']]) -ItemType Directory -Force > $null
#New-Item -Path $(Join-Path $rootpath $global:settings[$global:configRootKeys['SecureCertificatesSigningCertificatesNewCertificatesRelativePathConfigRootKey']]) -ItemType Directory -Force > $null
#'01' | Set-Content -Path $(Join-Path $rootpath $global:settings[$global:configRootKeys['SecureCertificatesSigningCertificatesSerialNumberRelativePathConfigRootKey']]) -Encoding $Encoding

New-Item -Path $(Join-Path $rootpath $global:settings[$global:configRootKeys['SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey']]) -ItemType File -EA SilentlyContinue > $null

# save the root of the CA Certificate Signing path
$CARootPath = $rootpath
# Save the three files needed for CA signing in the next section
$CADNHash = $DNHash
$CAEncryptionKeyPassPhrasePath = $EncryptionKeyPassPhrasePath
$CAEncryptedPrivateKeyPath = $EncryptedPrivateKeyPath
$CACertificatePath = $CertificatePath

# Create SSL Server Certificate(s) for all computers in the organization's workgroup
# ToDo: use the machine and node settings
$ComputerMames = @('ncat016', 'ncat040', 'nact-ltb1', 'ncat-ltjo', 'utat01', 'utat022')
$ComputerMames | ForEach-Object { $CN = $_

  # Define a DistinguishedNameHash for the SSL Server Certificate Request for each computer
  $DNHash = New-Object PSObject -Property @{
    CN               = $CN
    EmailAddress     = 'SecurityAdminsList@ATAPUtilities.org'
    Country          = 'US'
    StateOrTerritory = ''
    Locality         = ''
    Organization     = 'ATAPUtilities.org'
    OrganizationUnit = 'Development'
    #DNAsFileNameReplacementPattern                = 'CN="{0}",OU="{1}",O="{2}",C="{3}"'
    #SANAsParameterReplacementPattern = 'E="{0}"'
    #ExtendedKeyUseage                        = 'serverAuth'
  } | New-DistinguishedNameHash

  # Create an EncryptionPassPhrase file
  $Encoding = 'UTF8'

  # $EncryptionKeyPassPhraseCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey']] $global:settings[$global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']]
  # $EncryptionKeyPassPhrasePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey']] -CrossReferenceFilePath $EncryptionKeyPassPhraseCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey']]
  $EncryptionKeyPassPhrasePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey']] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey']]
  New-EncryptionKeyPassPhraseFile -PassPhrasePath $EncryptionKeyPassPhrasePath
  # validate the EncryptedPrivateKeyPath exists and is non-zero
  if (Test-Path -Path $EncryptionKeyPassPhrasePath -PathType Leaf) {
    if (-not (Get-ItemPropertyValue -Path $EncryptionKeyPassPhrasePath -Name 'Length')) {
      throw "New-EncryptionKeyPassPhraseFile created 0-length EncryptionKeyPassPhrase at $EncryptionKeyPassPhrasePath"
    }
  }
  else {
    throw "New-EncryptionKeyPassPhraseFile failed to create the EncryptionKeyPassPhrase at $EncryptionKeyPassPhrasePath"
  }

  # Create an EncryptedKey file
  $ECCurve = 'P-256'

  # $EncryptedPrivateKeyCrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']] $global:settings[$global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']]
  # $EncryptedPrivateKeyPath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey']] -CrossReferenceFilePath $EncryptedPrivateKeyCrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']]
  $EncryptedPrivateKeyPath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey']] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']]
  New-EncryptedPrivateKey -ECCurve $ECCurve -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath
  # validate the EncryptedPrivateKeyPath exists and is non-zero
  if (Test-Path -Path $EncryptedPrivateKeyPath -PathType Leaf) {
    if (-not (Get-ItemPropertyValue -Path $EncryptedPrivateKeyPath -Name 'Length')) {
      throw "New-EncryptedPrivateKey created 0-length EncryptedPrivateKey at $EncryptedPrivateKeyPath"
    }
  }
  else {
    throw "New-EncryptedPrivateKey failed to create the EncryptedPrivateKey at $EncryptedPrivateKeyPath"
  }


  # Create a SSL Server Certificate Request
  # Define the SubjectAlternateName (SAN) needed, put it into a temporary extensions file
  ("DNS.1=$CN")
  # ToDo : add ParameterSet for custom openSSL configuration file, with and without obsfucation
  # $CertificateRequestConfigPath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesOpenSSLConfigsPathConfigRootKey']] 'SSLCertificateTemplate.cnf'
  # New-CertificateRequest -DistinguishedNameHash $DNHash -CertificateRequestConfigPath $CertificateRequestConfigPath -CertificateRequestPath $CertificateRequestPath
  # ToDo: obsfucation
  # $CrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesCertificateRequestsPathConfigRootKey']] $global:settings[$global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']]
  # $CertificateRequestPath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesSSLServerCertificateRequestBaseFileNameConfigRootKey']] -CrossReferenceFilePath $CrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificateRequestsPathConfigRootKey']]
  $CertificateRequestPath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesSSLServerCertificateRequestBaseFileNameConfigRootKey']] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificateRequestsPathConfigRootKey']]
  # ToDo: Add SAN
  New-CertificateRequest -DistinguishedNameHash $DNHash -CertificateRequestPath $CertificateRequestPath
  # Validation
  if (Test-Path -Path $CertificateRequestPath -PathType Leaf) {
    if (-not (Get-ItemPropertyValue -Path $CertificateRequestPath -Name 'Length')) {
      throw "New-CertificateRequest created 0-length CertificateRequest at $CertificateRequestPath"
    }
  }
  else {
    throw "New-CertificateRequest failed to create the CertificateRequest at $CertificateRequestPath"
  }
  # print out the certificate request details
  # openssl req -text -in $CertificateRequestPath -noout

  # Create a signed SSL Server Certificate
  $ValidityPeriod = 368
  $ValidityPeriodUnits = 'days'
  # $CrossReferenceFilePath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']] $global:settings[$global:configRootKeys['SecureCertificatesCrossReferenceFilenameConfigRootKey']]
  # $CertificatePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesSSLServerCertificateBaseFileNameConfigRootKey']] -CrossReferenceFilePath $CrossReferenceFilePath -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']]
  $CertificatePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesSSLServerCertificateBaseFileNameConfigRootKey']] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']]

  # Write-PSFMessage -Level Important -Message $(Write-HashIndented -initialIndent 0 -indentIncrement 0 -hash $([ordered]@{
  #       EncryptionKeyPassPhrasePath = $EncryptionKeyPassPhrasePath
  #       EncryptedPrivateKeyPath     = $EncryptedPrivateKeyPath
  #       CertificateRequestPath      = $CertificateRequestPath
  #       CertificatePath             = $CertificatePath
  #       CAEncryptionKeyPassPhrasePath = $CAEncryptionKeyPassPhrasePath
  #       CAEncryptedPrivateKeyPath   = $CAEncryptedPrivateKeyPath
  #       CACertificatePath           = $CACertificatePath
  #     }))

  #$env:OPENSSL_SIGNINGCERTIFICATES_DIR = $CARootPath
  #$CASigningCertificatesSerialNumberPath = Join-Path $CARootPath $global:settings[$global:configRootKeys['SecureCertificatesSigningCertificatesSerialNumberRelativePathConfigRootKey']]
  $CASigningCertificatesCertificatesIssuedDBPath = Join-Path $CARootPath $global:settings[$global:configRootKeys['SecureCertificatesSigningCertificatesCertificatesIssuedDBRelativePathConfigRootKey']]
  #$CASigningCertificatesNewCertificatesPath = Join-Path $CARootPath $global:settings[$global:configRootKeys['SecureCertificatesSigningCertificatesNewCertificatesRelativePathConfigRootKey']]

  New-SignedCertificate -CertificateRequestPath $CertificateRequestPath `
    -CACertificatePath $CACertificatePath -CAEncryptedPrivateKeyPath $CAEncryptedPrivateKeyPath -CAEncryptionKeyPassPhrasePath $CAEncryptionKeyPassPhrasePath `
    -CASigningCertificatesCertificatesIssuedDBPath $CASigningCertificatesCertificatesIssuedDBPath `
    -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits -CertificatePath $CertificatePath `
    # -CASigningCertificatesNewCertificatesPath $CASigningCertificatesNewCertificatesPath `
    #-CASigningCertificatesSerialNumberPath $CASigningCertificatesSerialNumberPath `

  # ToDo: I cannot get -out to work, so must rename the serialnumber.pem file to the CertificatePath
  # Read the IssuedDb and get all certificates that match the common name, then the 3rd field from each line, and make a Path to that file
  $CertificateDir = Split-Path -Path $CertificatePath -Parent
  $matchingCerts = ((gc $CASigningCertificatesCertificatesIssuedDBPath) -match "/CN=$($DNHash.CN)/") | % { ($_ -split '\s+')[2] } | % { Join-Path $CertificateDir $($_ + '.pem') }
  # Only one of them should exist
  $certToRename = $matchingCerts | % { if (Test-Path $_) { $_ } }
  # rename that one to the expected CertifictePath
  Move-Item $certToRename $CertificatePath -Force

  # Validation
  if (Test-Path -Path $CertificatePath -PathType Leaf) {
    if (-not (Get-ItemPropertyValue -Path $CertificatePath -Name 'Length')) {
      throw "New-SignedCertificate created 0-length Certificate at $CertificatePath"
    }
  }
  else {
    throw "New-SignedCertificate failed to create the Certificate at $CertificatePath"
  }
  # print out the certificate details
  # openssl req -x509 -text -in $CertificatePath -noout

  # [Enable HTTPS on IIS](https://techexpert.tips/iis/enable-https-iis/)
  # To import a SSLServer certificate into IIS, the file to be imported must combine the certificate and the private key
  $CertificatePFXPath = $CertificatePath -replace 'pem$','pfx'
  openssl pkcs12 -export -inkey $EncryptedPrivateKeyPath -in $CertificatePath -out $CertificatePFXPath
}

# [How can I set up Jenkins CI to use https on Windows?](https://stackoverflow.com/questions/5313703/how-can-i-set-up-jenkins-ci-to-use-https-on-windows)

####### This portion installs a CA as a Root CA on a list of computers
# $CACertificate = $CACertificatePath | ?{$_.Filename -match "CN_$($CADNHash.CN)__" }

##
Function Register-RootCA {}
# ToDo: Add -ComputerName and -RunAs arguments, and do this in a loop
# Install the new CA to the Certificate Store in the LocalMachine's Trusted Root subdirectory
$RootCACertStoreLocation = 'cert:\LocalMachine\Root'
# ToDo: error handling
# Import-Certificate requires the 32-bit PKI module to be imported into the session
Import-Module -Name 'C:\Windows\System32\WindowsPowerShell\v1.0\Modules\PKI\pki.psd1'
Import-Certificate -FilePath $CACertificatePath -CertStoreLocation $RootCACertStoreLocation >$null
# endregion Register-RootCA

# Install the SSLServer certificate appropriate to this machine
# Install it to the machinese personal certificate store
$SSLServerCertStoreLocation = 'cert:\LocalMachine\My'
# Since most security certificates depend on the DNS-resolved HostName, and because the following method is cross-platform...
# [How to Get a Computer Name with PowerShell](https://adamtheautomator.com/powershell-get-computer-name/)
$hostName = ([System.Net.DNS]::GetHostByName($Null)).Hostname

$SSLServerCertificatePath = Get-ChildItem $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']] |
Where-Object { $_.name -match "CN_$($hostName)__" }

Import-Certificate -FilePath $SSLServerCertificatePath -CertStoreLocation $SSLServerCertStoreLocation -Verbose # >$null

# Add the Certificate to the jenkins keystore if this computer has the JenkinsControllerNode role

# Add the pfx Certificate to IIS if this computer has IIS installed

# Store the Server SSL Certificate information in a Secret Vault# Store the Server SSL Certificate information in a Secret Vault
# # The Secret Vault MUST BE CREATED by an administrator before this step can execute. This means the encryption key file and the encrypted password file must already exist
#
# $SecretVaultName = 'SecurityAdminSecretsSSLServerCertificates'
# $SecretVaultDescription = 'Location of the SSL Server identification Certificate files for Security Administrators'
# $ExtensionVaultModuleName = 'SecretManagement.Keepass'
# $KeyFilePath = Join-Path 'C:' 'Dropbox' 'Security', 'Certificates', 'EncryptedKeys', 'SecurityAdminSecretsSSLServerCertificatesEncryption.key'
# $EncryptedPasswordFilePath = Join-Path 'C:' 'Dropbox' 'Security', 'Vaults', 'EncryptedPasswordFiles', 'SecurityAdminSecretsSSLServerCertificatesEncryptedPassword.txt'
# $PasswordTimeout = 300
# $PathToKeePassDB = 'C:\KeePass\Local.ATAP.Utilities.kdbx'  # This is the identifier for the KeePassParameterSet
#
# Write-PSFMessage -Level Important -Message $(Write-HashIndented -initialIndent 0 -indentIncrement 0 -hash $([ordered]@{
#       SecretVaultName           = $SecretVaultName
#       SecretVaultDescription    = $SecretVaultDescription
#       ExtensionVaultModuleName  = $ExtensionVaultModuleName
#       KeyFilePath               = $KeyFilePath
#       EncryptedPasswordFilePath = $EncryptedPasswordFilePath
#       PasswordTimeout           = $PasswordTimeout
#       PathToKeePassDB           = $PathToKeePassDB
#     }))
#
# . C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-UsersSecretStoreVault.ps1
# Get-UsersSecretStoreVault -SecretVaultName $SecretVaultName -SecretVaultDescription $SecretVaultDescription -ExtensionVaultModuleName $ExtensionVaultModuleName -KeyFilePath $KeyFilePath -EncryptedPasswordFilePath $EncryptedPasswordFilePath -PathToKeePassDB $PathToKeePassDB
#
#
# # Store
# # Get the signed certificate from the location where the openssl CA command places it
# # Install the new SSL Server certificate to the Certificate Store in the LocalMachine's Personal
# #$CertStoreLocation = 'cert:\LocalMachine\My'
# # ToDo: error handling
# #Import-Certificate -FilePath $CACertificatePath -CertStoreLocation $CertStoreLocation >$null
#
#
# #}
#
# $ValidityPeriod = 1
# $ValidityPeriodUnits = 'years'
#
# #. rotateCa -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits
#
# # Store the Root CA information in Secret Vault
# # The Secret Vault MUST BE CREATED by an administrator before this step can execute. This means the encryption key file and the encrypted password file must already exist
#
# $SecretVaultName = 'SecurityAdminSecretsCurrentRootCA'
# $SecretVaultDescription = 'Location of the current root Ca files for Security Administrators'
# $ExtensionVaultModuleName = 'SecretManagement.Keepass'
# $KeyFilePath = Join-Path 'C:' 'Dropbox' 'Security', 'Vaults', 'KeyFiles', 'SecurityAdminSecrets.key'
# $EncryptedPasswordFilePath = Join-Path 'C:' 'Dropbox' 'Security', 'Vaults', 'PasswordFiles', 'SecurityAdminSecrets.txt'
# $PasswordTimeout = 300
# $PathToKeePassDB = 'C:\KeePass\Local.ATAP.Utilities.kdbx'  # This is the identifier for the KeePassParameterSet
#
# Write-PSFMessage -Level Important -Message $(Write-HashIndented -initialIndent 0 -indentIncrement 0 -hash $([ordered]@{
#       SecretVaultName           = $SecretVaultName
#       SecretVaultDescription    = $SecretVaultDescription
#       ExtensionVaultModuleName  = $ExtensionVaultModuleName
#       KeyFilePath               = $KeyFilePath
#       EncryptedPasswordFilePath = $EncryptedPasswordFilePath
#       PasswordTimeout           = $PasswordTimeout
#       PathToKeePassDB           = $PathToKeePassDB
#     }))
#
# . C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-UsersSecretStoreVault.ps1
# Get-UsersSecretStoreVault -SecretVaultName $SecretVaultName -SecretVaultDescription $SecretVaultDescription -ExtensionVaultModuleName $ExtensionVaultModuleName -KeyFilePath $KeyFilePath -EncryptedPasswordFilePath $EncryptedPasswordFilePath -PathToKeePassDB $PathToKeePassDB
#
# # Store the secret information about the current Root CA
# # Some vaults allow a secret to be changed, but others require a secret be deleted and then added
# # ToDo: handle errors if a secret cannot be found
# $SecretName = 'CAEncryptionKeyPassPhrasePath'
# Write-PSFMessage -Level Important -Message " EncryptionKeyPassPhrasePath = $EncryptionKeyPassPhrasePath"
# Remove-Secret -Name $SecretName -Vault $SecretVaultName
# Set-Secret -Name $SecretName -Vault $SecretVaultName -Secret $EncryptionKeyPassPhrasePath # -Metadata @{description = "Current Root CA Key PassPhrase Path"}
# $SecretName = 'CAEncryptedPrivateKeyPath'
# Remove-Secret -Name $SecretName -Vault $SecretVaultName
# Set-Secret -Name $SecretName -Vault $SecretVaultName -Secret $EncryptedPrivateKeyPath # -Metadata @{description = "Current Root CA Encrypted Private Key Path"}
# $SecretName = 'CACertificatePath'
# Remove-Secret -Name $SecretName -Vault $SecretVaultName
# Set-Secret -Name $SecretName -Vault $SecretVaultName -Secret $CertificatePath # -Metadata @{description = "Current Root CA Certificate Path"}
# # ToDo: add name of Certificte Signing server
# # ToDo: add path to the specific CA signing subdirectory on the Certificte Signing server
#
# # Retrieve the signing Certificate Authority Certificate from a Secret Vault
#
# $SecretVaultName = 'SecurityAdminSecretsCurrentRootCA'
# $SecretVaultDescription = 'Secrets for Security Administrators'
# $ExtensionVaultModuleName = 'SecretManagement.Keepass'
# $PathToKeePassDB = 'C:\KeePass\Local.ATAP.Utilities.kdbx'  # This is the identifier for the KeePassParameterSet
#
# $KeyFilePath = Join-Path 'C:' 'Dropbox' 'Security', 'Vaults', 'KeyFiles', 'SecurityAdminSecrets.key' # Join-Path $env:TEMP 'SecretVaultTestingEncryption.key'
# $EncryptedPasswordFilePath = Join-Path 'C:' 'Dropbox' 'Security', 'Vaults', 'PasswordFiles', 'SecurityAdminSecrets.txt' # $env:TEMP 'SecretVaultTestingEncryptedPassword.txt'
#
# $PasswordTimeout = 300
# . C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Security.Powershell\public\Get-UsersSecretStoreVault.ps1
# Get-UsersSecretStoreVault -SecretVaultName $SecretVaultName -SecretVaultDescription $SecretVaultDescription -ExtensionVaultModuleName $ExtensionVaultModuleName -KeyFilePath $KeyFilePath -EncryptedPasswordFilePath $EncryptedPasswordFilePath -PathToKeePassDB $PathToKeePassDB
#
# # Get the current root CA certificate files
# $SecretName = 'CAEncryptionKeyPassPhrasePath'
# $CAEncryptionKeyPassPhrasePath = ConvertFrom-SecureString -SecureString (Get-Secret -Name $SecretName -Vault $name) -AsPlainText
# $SecretName = 'CAEncryptedPrivateKeyPath'
# $CAEncryptedPrivateKeyPath = ConvertFrom-SecureString -SecureString (Get-Secret -Name $SecretName -Vault $name) -AsPlainText
# $SecretName = 'CACertificatePath'
# $CACertificatePath = ConvertFrom-SecureString -SecureString (Get-Secret -Name $SecretName -Vault $name) -AsPlainText
#
# # Validation
# Write-PSFMessage -Level Critical -Message $(Write-HashIndented -initialIndent 0 -indentIncrement 0 -hash $([ordered]@{
#       CAEncryptionKeyPassPhrasePath = $CAEncryptionKeyPassPhrasePath
#       CACertificatePath             = $CACertificatePath
#       CAEncryptedPrivateKeyPath     = $CAEncryptedPrivateKeyPath
#     }))
#
#
# # The following will print out information about the CACertificate
# openssl x509 -text -in $CACertificatePath -noout
#
#
