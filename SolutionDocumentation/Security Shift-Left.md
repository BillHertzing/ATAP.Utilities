# Security in the Libraries, Packages and CI/CD pipeline

If you are viewing this `Security Shift-Left.md` in GitHub, [here is this same Security Shift-Left on the documentation site](http://nope.com/nope.html)

## <a id="Introduction" />Introduction

Security is everyone's business in software development. The applications and libraries being developed as 'product' should have security as a first-class citizen. Automated scanning tools should, during the build, inspect and analyze the code being developed for known security flaws and best practices. The 3rd-party SW being used in the product (the items in the Software Bill of Materials (SWBOM)) should report their compliance with security best practices, and these 3rd party softwares and their security score should made available in the build artifacts included in the 'product' packages.

While there are multiple security concerns in an organizations, this document is going to focus on securing the 'secrets' that are used in the Development and CI/CD process to produce an application. ToDo: Add a reference to another document that focuses on securing user information within a generated application.

Every organization has "secrets" that are used in the Development and CI/CD processes. These secrets must be protected, because they are often linked to 3rd-party software that costs money to execute. Loss and then misuse of the secrets could cost an organization a lot of money.

The CI/CD pipeline will need access to "secrets" that authorize access to certain sensitive information. For example, credentials to access Git, credentials to access cloud storage locations, Code Signing Certificates, SHA generation, database credentials, passwords for service accounts, oAuth credentials, API access tokens, all need to be secured and protected from disclosure.

The deployment servers to which 'product' is deployed are usually protected by credentials to ensure only authorized production packages are deployed.

The developer's machines all need individual security to handle user and Service passwords, authorization tokens from cloud services,

Securing secrets used in the development process, the CI/CD tools, and the final production products is a difficult tricky task, and there are a lot of ways to go about it. The ATAP.Utilities use a three-stage mechanism.

## <a id="Overview" />Overview

This document is under construction. There are design false starts here, as limitations in current OSS modules and libraries have been discovered during implementation attempts.

## <a id="GettingStarted" />Getting Started

There is a lot to do!

## <a id="Prerequisites" />Prerequisites

### OpenSSL for encryption and Certificates

This article
[How do you sign a Certificate Signing Request with your Certification Authority?](https://stackoverflow.com/questions/21297139/how-do-you-sign-a-certificate-signing-request-with-your-certification-authority) See the accepted answer by JWW
has extensive information on setting up SSL Configuration files

OpenSSL for Windows:

`choco install OpenSSL.Light`

If the choco installation adds the OpenSSL bin location to the path (there will be a message like `PATH environment variable does not have C:\Program Files\OpenSSL\bin in it. Adding...`), then the installation is complete. However, if there is no message then the OpenSSL bin location should be added to the path.

Add `C:\Program Files\OpenSSL\bin` to the existing machine-scope path (so any automation service account can access the programs)

can be done in the machine-wide profile for a better cross-platform experience

```Powershell
$Path = [Environment]::GetEnvironmentVariable("PATH", "Machine") + [IO.Path]::PathSeparator + (join-path 'C:' 'Program Files' 'OpenSSL','bin' )
[Environment]::SetEnvironmentVariable( "Path", $Path, "Machine" )
```

or (Windows only)

```Powershell
  $oldpath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path
  $newpath = $oldpath + [IO.Path]::PathSeparator + (join-path  'C:' 'Program Files' 'OpenSSL','bin' )
  Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath
```

Download an OpenSSL configuration file (do this in the C:\Dropbox\SecretManagement\CARoot directory of the machine(s) that are the organization's CA server(s) )
ToDo: use machine settings for the CloudSyncedSecureBasePath and/or the CARoot subdirectory

```Powershell
$OpenSSLConfigurationPath = 'C:\Dropbox\Security\CARoot\openssl.cnf'
Invoke-WebRequest 'http://web.mit.edu/crypto/openssl.cnf' -OutFile $OpenSSLConfigurationPath
```

Add a machine-wide environment variable (windows only)

```Powershell
  Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name OPENSSL_CONF -Value $OpenSSLConfigurationPath
```

### PKI modules for Certificate Management

The pki module does not autoload, it has to be done manually if not yet done
`Import-Module -Name C:\Windows\System32\WindowsPowerShell\v1.0\Modules\PKI\pki.psd1`

### Secure Cloud-based Disaster Recovery Location

There needs to be a single place in the cloud where secrets are kept in plaintext for disaster recovery.
The DisasterRecoveryPath is defined in the global settings

```Powershell
$DisasterRecoveryPath = $global:settings[$global:ConfigRootKeys[DisasterRecoveryPathConfigRootKey]]
```

### Secure Physical Disaster Recovery Location

There needs to be a place with high physical security where secrets are kept in plaintext for disaster recovery, often a USB Stick regularly updated and put into a safe deposit box.

```Powershell
$DisasterRecoveryBackupPath = $global:settings[$global:ConfigRootKeys[DisasterRecoveryBackupPathConfigRootKey]]
```

### Secure Cloud-based Encrypted Secrets Location

### Security Analysis Tools Prerequisites

- the Github service that scans repositories and PRs

- Dependabot for listing dependency packages

- License analysis

#### Data Encryption Certificates Prerequisites

For Installation on Windows, the CertReq.exe program must be available
ToDo: write details For Installation on Linux

#### Code Signing Certificates Prerequisites

#### Database Credentials Prerequisites

#### Cloud Storage Credentials Prerequisites

For Windows:
Dropbox:
Dropbox Vault:
OneDrive:
GoogleDrive:

##### Dropbox Access Credentials Prerequisites

##### GoogleDrive Access Credentials Prerequisites

##### OneDrive Access Credentials Prerequisites

#### On-Premise Hot Backup locations Prerequisites

For Windows:

#### Off-Premise Cold Backup locations Prerequisites

## Overview

### Disaster Recovery

All secrets are stored in plaintext in a subdirecotry rooted at DisasterRecoveryPath and also in another subdirecotry rooted at DisasterRecoveryBackup path. These actual locations are whatever locations the organizations feel is their most secure storage.

## Git Credentials

## SCM Provider Credentials

### GitHub Credentials

## Database Credentials

### MSSQL Server Credentials

### SQLLite Credentials

### MySQL Credentials

## ServiceAccount Credentials

## Cloud Storage Credentials

### Dropbox Access Credentials

### GoogleDrive Access Credentials

### Local Network File Shares Credentials

### Local Web Server Read and Write Credentials

### Certificates

ATAP Utilities uses a PKI infrastructure supplied as part of a module called ATAP.Utilities.Security.

```PlantUML
@startuml
(*) --> "Define Configuration Constants"
"Define Configuration Constants" --> "Define Machine Roles"
"Define Machine Roles" --> "Define Machine Settings for each Role"
"Define Machine Settings for each Role" --> "Define values for Machine Settings for each Role"
"Define values for Machine Settings for each Role" --> (*)
(*) -> "Setup Master PKI Server machine"
"Setup Master PKI Server machine" -> "Validate Master PKI Server machine"
"Validate Master PKI Server machine" -> (*)
@enduml
```

```PlantUML
@startwbs
*:Secure Cloud-Synced Directory Root
ACL (or directory/group) role-based protections;
** Vaults
*** KeyFiles
*** MasterPasswordFiles
*** VaultDatabases
** Certificates
***_ DefaultConfigurationFile
*** CertificateRequests
**** SSL Server Certificate Requests
*****_ utat01.csr
*****_ utat022.csr
*****_ ncat016.csr
**** SSL Client Certificate Requests
**** CodeSigning Certificate Requests
*****_ ATAPUtilities.csr
*** EncryptedKeys
*** EncryptionPassPhraseFiles
*** Certificates
**** Root CA Certificates
**** Intermediate Signing Certificates
**** SSL Server Certificate
*****_ utat01.crt
*****_ utat022.crt
*****_ ncat016.crt
**** SSL Client Certificate
**** CodeSigning Certificate
*****_ ATAPUtilities.crt47
** CertificateSigning
*** RootCACertificate1
**** PrivateKeys
**** NewCertificates
****_ CertificatesIssued.txt
****_ serial
*** IntermediateCACertificate1
**** ...
*** IntermediateCACertificate2
**** ...
@endwbs
```

#### OpenSSL Default Configuration File

An organization should not directly use the default openSSL.cnf file distributed with the OpenSSL tools. An organization should create it's own default openssl Configuration file based on the default file provided by OpenSSL.org, This prevents an update to the default OpenSSL configuration file from directly impacting an organization.

#### OpenSSL Subject, Distinguished Names, and Subject Alternative Names

All Certificate Requests and Certificates require a Subject.
Certificate creation starts with the Subject, SubjectAlternativeName, and the type of certificate (template)
[Distinguished Names](https://ldapwiki.com/wiki/Distinguished%20Names)

Example:

```Powershell
  $DNHash = New-Object PSObject -Property @{
    CN                                       = 'ATAPUtilities.org'
    EmailAddress                             = 'SecurityAdminsList@ATAPUtilities.org'
    Country                                  = 'US'
    StateOrTerritory                         = 'UT'
    Locality                                 = 'HD'
    Organization                             = 'ATAPUtilities.org'
    OrganizationUnit                         = 'Development'
    DNAsFileNameReplacementPattern                = 'CN="{0}",OU="{1}",O="{2}",L="{3}",ST="{4},C="{5}"'
    SANAsParameterReplacementPattern = 'E="{0}"'
    #KeyUseage                                = @('critical', 'cRLSign', 'digitalSignature', 'keyCertSign')
    #ExtendedKeyUseage                        = 'CA:TRUE'
    # ExtendedKeyUseage = @('critical','codeSigning')
  } | New-DistinguishedNameHash
```

#### File Name Obfuscation

All of the cmdlets which generate filepaths can take an additional argument `-CrossReferenceFile`. If supplied, the cmdlet will return a file path ending in a guid. The CrossReferenceFile value is a persistent storage for holding the relationship between the Distinguished Name as Filename, and the obfuscated GUID filename

#### PassPhrase Files vs. Passwords

Putting the password on the command line with, for example -passin pass:abcd1234 is insecure, as command line arguments are visible to any other process running on the computer. A better solution is to create an Encryption Key PassPhrase file and an Encrypted Private Key file, and supply OpenSLL with `-key EncryptedPrivateKeyPath -passin file:EncryptionKeyPassPhrasePath`

#### Creating a PKI infrastructure for an organization

The script `PKIForNewOrg.ps1` will create most of infrastructure needed to support PKI for an organization. Some of the steps must be performed manually the very first time, in order to enable PSRemoting on computers where that is not yet enabled. At a high level, it follows these steps:

- Confirm the installation and accessability of OpenSSL executables and the presence of openSSL environment variables
- Confirm/Create the necessary directory structure at a secure cloud-synced location
  - SecureCloudRootPath
  - SecureCertificatesPath
  - SecureCertificatesEncryptionPassPhraseFilesPath
  - SecureCertificatesEncryptedKeysPath
  - SecureCertificatesOpenSSLConfigsPath
  - SecureCertificatesCertificateRequestsPath
  - SecureCertificatesCertificatesPath
  - SecureCertificates CA PathPattern
  - SecureCertificates CA Root PathPattern
  - SecureCertificates CA Intermediate PathPattern
  - SecureCertificates CodeSigning PathPattern
  - SecureCertificates DataEncryption PathPattern
  - SecureCertificates SSLServerCertificates PathPattern
  - SecureCertificates SSLClientCertificates PathPattern
- Define a DistinguishedNameHash for the Root CA of the organization
- Create a Root CA
  - Create an EncryptionPassPhrase file
  - Create an EncryptedKey file
  - Create a CA Certificate
- Confirm/Create the necessary directory structure for signing certificates with the CA at a secure cloud-synced location


- Create SSL Server Certificate(s) for all computers in the organization's workgroup
  - Define a DistinguishedNameHash for the SSL Server Certificate Request for each computer
  - Create an EncryptionPassPhrase file
  - Create an EncryptedKey file
  - Create a SSL Server Certificate Request
  - Create a signed SSL Server Certificate
  - Copy the signed SSL Server Certificate from the signing certificate's directory structure to the organization's directory structure

The following steps must be taken manually by a security administrator on any computer that does not have PSRemoting enabled
- Deploy the Root CA to each computer in the workgroup
- Deploy the appropriate SSL Server certificate to each computer in the organization's workgroup


##### Validating needed Tools, Environment variables and Directory Structure

The script `ValidatePKIPrerequisites.ps1` can be run on any machine to determine if all of the PKI prerequisites are met.

##### Define a DistinguishedNameHash for the Root Certificate Authority (CA) of the organization

The Root CA should have just a CN and an Organization, and they should be the same string

##### Root Certificate Authority (CA) Certificate

Every organization needs a Root CA Certificate, to sign internal Certificates. The Root CA Certificate should be used to sign Intermediate Signing Certificates, and nothing else. Creation of a Root CA Certificate requires a PassPhrase File, an EncryptedeKeyFile, and an openSSL Configuration file.

###### Create an Encryption Key PassPhrase File


```Powershell
  $EncryptionKeyPassPhrasePath =  Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey'] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey']]
  New-EncryptionKeyPassPhraseFile -PassPhrasePath $EncryptionKeyPassPhrasePath
```

##### Create an Encrypted Private Key File

Use a Ecliptic Curve encryption algorithm

```powershell
  $EncryptedPrivateKeyPath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCAEncryptedPrivateKeyBaseFileNameConfigRootKey'] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']]
  New-EncryptedPrivateKey -ECCurve $ECCurve -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath

```

##### Generate the Root Certificate Authority Certificate

The Root CA Certificate can be generated without first needing a CertificateSigningRequest

```Powershell
  $CertificatePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCACertificateBaseFileNameConfigRootKey'] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']]
  New-CACertificate -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits -CertificatePath $CertificatePath
```

##### Create the Directory structure needed to sign Certificates

##### Create a custom OpenSSL Configuration File for the Root CA

There are a few settings needed to sign a Certificate with a CA, that cannot be modified / set on the command line. These few settings MUST be configured in the OpenSSL configuration file. Luckliy, they can be done with environment variables

OPENSSL_SIGNINGCERTIFICATES_DIR
dir		= C:/Dropbox/Security/Certificates/SigningCertificates/Root		# Where everything is kept
#private_key	= $dir/PrivateKeys/cakey.pem # The private key
serial		= $dir/serial 		# The current serial number
database	= $dir/CertificatesIssued.txt	# database index file.
new_certs_dir	= $dir/NewCertificates	# default place for new certs.
certs		= $dir/Certificates		# Where the issued certs are kept
#crl		= $dir/crl.pem 		# The current CRL
#crl_dir		= $dir/crl		# Where the issued crl are kept


##### Install the Root Certificate Authority Certificate

Add the new Root Certificate Authority certificate to all machines in the workgroup

Note that powershell remoting depends on having a trusted SSL certificate for this purpose.
Trusting an internally generated SSL certificate requires an internal Root Certificate Authority certificate
Therefore Powershell remoting cannot be used to install an internal Root Certificate Authority certificate on a machine which does not yet have PS-remoting working

Repeat the following commands on each machine in the workgroup, as an administrator

- Windows

  ```Powershell
  $CertificatePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCACertificateBaseFileNameConfigRootKey'] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']]
  $RootCACertStoreLocation = 'cert:\LocalMachine\CA'
  # Import the 32-bit Desktop Powershel PKI module
  Import-Module -Name "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\PKI\pki.psd1"
  Import-Certificate -FilePath $CertificatePath -CertStoreLocation $RootCACertStoreLocation
  ```

- *nix
  ToDo: Install the Root Certificate Authority Certificate has been installed on *nix
- MacOS
  ToDo: Install that the Root Certificate Authority Certificate has been installed on MacOS
- IOS
  ToDo: Install that the Root Certificate Authority Certificate has been installed on IOS
- Android
  ToDo: Install that the Root Certificate Authority Certificate has been installed on Android

##### Validate that the Root Certificate Authority Certificate has been installed

Repeat the following commands on each machine in the workgroup, as an administrator

- Windows

  ```powershell
  (ls $RootCACertStoreLocation).subject | Where-Object{$_ -match "CN=""$Subject.CN""}
  ```

- *nix
  ToDo: Validate that the Root Certificate Authority Certificate has been installed on *nix
- MacOS
  ToDo: Validate that the Root Certificate Authority Certificate has been installed on MacOS
- IOS
  ToDo: Validate that the Root Certificate Authority Certificate has been installed on IOS
- Android
  ToDo: Validate that the Root Certificate Authority Certificate has been installed on Android

##### Add the Root Certificate Authority Certificate to the Trusted Roots

Example

- Windows
  See [Create Your Own SSL Certificate Authority for Local HTTPS Development](https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/) for instructions using the MMC snap-in
  ToDO: Powershell way - (Need to figure out teh proper cert store)

- \*nix
- MacOS
- IOS
- Android

#### Intermediate Certificate Authority Certificates

##### Create an SSL Server Certificate

There are many scenarios that require a trusted SSL Certificate to authenticate a specific server. The examples below will create a SSL certificate for a server DN. Among other things, it can be used to support Powershell remoting in a workgroup environment.

Certificate creation starts with the DintiguishedNameHash  # Subject, SubjectAlternativeName, and the type of certificate (template)
[Distinguished Names](https://ldapwiki.com/wiki/Distinguished%20Names).

Also needed are the certificate's ValidityPeriod and ValidityPeriodUnits

Example:

```Powershell
$DNHash = @{
CN='utat01'
Country='US'
StateOrTerritory=''
Organization='ATAPUtilities.org'
OrganizationUnit='Development'
Email= 'SecurityAdminsList@ATAPUtilities.org'
DNAsFileNameReplacementPattern = 'CN="{0}",OU="{1}",O="{2}",ST="{4},C="{3}"'
SANAsParameterReplacementPattern = 'E="{0}"'
} | New-DistinguishedNameHash

$CertificateRequestConfigPath = Join-Path $global:settings[$global:configRootKeys['SecureCertificatesOpenSSLConfigsPathConfigRootKey']]'SSLCertificateRequestTemplate.txt'

```

##### Create an Encryption Key PassPhrase File for the SSL Certificate Private and Public Key Pair

```Powershell
$EncryptionKeyPassPhrasePath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesSSLServerPassPhraseFileBaseFileNameConfigRootKey'] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']]
New-EncryptionKeyPassPhraseFile -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath
```

##### Create an SSL Certificate Private and Public Key Pair

Example

```powershell
# Out filename template using Subject and SubjectAlternativeName
$EncryptedPrivateKeyPath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesSSLServerEncryptedPrivateKeyBaseFileNameConfigRootKey'] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptedKeysPathConfigRootKey']]
New-EncryptedPrivateKey -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath  -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath  -KeySize $KeySize
# generate a private key using maximum key size of 2048
# key sizes can be 512, 758, 1024, 1536 or 2048.
openssl genrsa -des3 -passout file:$EncryptionKeyPassPhrasePath -pubout -outform PEM -out $EncryptedPrivateKeyPath $KeySize
# using the -des3 option encrypts the private key, and requires a password.
# putting the password on the command line with -passout pass:abcd1234 is insecure, as command line arguments are visible to any onther process
#  A better solution to providing a password is to use the password to populate a temporary file in a secure location
#  and use -passout file:passphrase.txt
# openssl genrsa -des3 -out $SSLPrivateKeyPath 2048
# openssl genrsa -des3 -passout file:$EncryptionKeyPassPhrasePath -pubout -outform PEM -out $EncryptedPrivateKeyPath $KeySize
```

##### Generate the SSL Certificate Request

```Powershell
$CertificateRequestPath = Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName 'SSLCertificateRequest.csr' -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificateRequestsPathConfigRootKey']]
Create-CertificateRequest -Template $CertificateRequestConfigPath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -CertificateRequestPath $CertificateRequestPath
```

##### Generate the SSL Certificate and sign it with the Root Certificate Authority Certificate

Note that to do this, the function needs to know the CertificatePath, EncryptionKeyPassPhrasePath, the EncryptedPrivateKeyPath, the serial number file path, and the Certificate index filepath for the RootCA that we want to sign it with

###### Get the necessary Root Certificate Authority Certificate information from the secret vault

Paths should be relative to the CloudSecureBase location

```Powershell
$CACertificateInfo = Get-CertificateFromVault {()
  return @{CertificatePath = ; EncryptedPrivateKeyPath = ; }
}
```

Example

##### Create and sign the SSL Certificate

````Powershell
$CertificatePath = Get-DistinguishedNameQualifiedFilePath  -BaseFileName 'SSLCertificate.crt' -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']]
$ValidityDays = 3650
Create-CertificateAndSign -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -CertificateRequestPath $CertificateRequestPath -validityDays $validityDays -CertificatePath $CertificatePath -CACertificatePath $CACertificateInfo.CertificatePath -CAEncryptedPrivateKeyPath $CACertificateInfo.EncryptedPrivateKeyPath -CAEncryptionKeyPassPhrasePath $CACertificateInfo.EncryptionKeyPassPhrasePath
$WinRMSSLCertificatePath -days 3650

````

#### Save the SSL Certificate into a Vault

Use a specific vault for least privilege

Keep the following until testing proves them unnecessary (are the RootCA Cert and teh SSL cert private/public key pairs the same? what's the "best" way to generate the PP Key pair)

##### Create a private/public key pair for the SSL certificate

```Powershell
$WinRMSSLPrivateKeyPath = 'C:\Dropbox\SecretManagement\CARoot\PrivateKeys\WinRMSSLKey.private'
$WinRMSSLPrivateKeyPassphraseFilePath = join-path $global:settings[$global:ConfigRootkeys['SecureTemporaryDirectoryConfigrootKey']] 'WinRMSSLPrivateKeyPassphrase.txt'
# ToDo: make up a random passphrase and save it to a secret vault? Also plaintext backup for disaster recovery, only to USB. The write it to the temporary direcotry
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out $WinRMSSLPrivateKeyPath
# openssl genpkey -algorithm RSA -des3 -passout file:$WinRMSSLPrivateKeyPassphraseFilePath -pkeyopt rsa_keygen_bits:2048 -out $WinRMSSLPrivateKeyPath
```

Create a SSL certificate request (can be done on any machine)

```Powershell
# ToDo: The following lacks a Certificate Request, need to generate a template and a script to generate a populated CSR
$CARootCN='utat022'
$CARootCountry='US'
$CARootStateOrTerritory='UT'
$CARootOrganization='ATAPUtilities.org'
$CARootOrganizationUnit='Development'
$CARootEmail= 'SecurityAdminsList@ATAPUtilities.org'
$CARootSubjectPatternReplacement = 'CN="{0}",OU="{1}",O="{2}",ST="{4},C="{3}"'
$CARootSubject = $CARootSubjectPatternReplacement -f $CARootCN, $CARootOrganizationUnit, $CARootOrganization, $CARootStateOrTerritory, $CARootCountry
$CARootSubject
$WinRMSSLCertificateRequestPath = "C:\Dropbox\SecretManagement\CARoot\CertificateRequests\WinRMSSLCertificateRequest.csr"
# ToDo add email as SAN, and investigate challenge passphrase and optional company name
openssl req -new -key $WinRMSSLPrivateKeyPath -out $WinRMSSLCertificateRequestPath
```

validate the SSL certificate request (can be done on any machine)

```Powershell
# ToDo: Output to a file for automated checking
openssl req -text -noout -verify -in $WinRMSSLCertificateRequestPath
```

Create a SSL Certificate and sign it with the organization's CA Root Certificate

```Powershell
$WinRMSSLCertificatePath = Join-path 'C:\Dropbox\SecretManagement\CARoot\Certificates' 'WinRMSSLCertificate.crt'
openssl x509 -req -in $WinRMSSLCertificateRequestPath -CA $RootCAPath -CAkey $RootCAPrivateKeyPath -CAcreateserial -out $WinRMSSLCertificatePath -days 3650

```

Combine the certificate and the key into a .pfx fileConvert the certificate toa .pfx file


Install the SSL Certificate onto every machine where PSRemoting is desired



[How To Set up OpenSSL on Windows 10 (PowerShell)](https://adamtheautomator.com/openssl-windows-10/)
[Create Your Own SSL Certificate Authority for Local HTTPS Development](https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/)
[PEM, DER, CRT, and CER: X.509 Encodings and Conversions](https://www.ssl.com/guide/pem-der-crt-and-cer-x-509-encodings-and-conversions/)
[How to Create SSL Certificates for Development](https://betterprogramming.pub/how-to-create-ssl-certificates-for-development-861237235933)
[What is the purpose of the -nodes argument in openssl?](https://stackoverflow.com/questions/5051655/what-is-the-purpose-of-the-nodes-argument-in-openssl)
[How to generate an openSSL key using a passphrase from the command line?](https://stackoverflow.com/questions/4294689/how-to-generate-an-openssl-key-using-a-passphrase-from-the-command-line)
[Can I add a password to an existing private key?](https://security.stackexchange.com/questions/59136/can-i-add-a-password-to-an-existing-private-key)
[21 OpenSSL Examples to Help You in Real-World](https://geekflare.com/openssl-commands-certificates/)
[System Store Locations](https://docs.microsoft.com/en-us/windows/win32/seccrypto/system-store-locations)
[How to add X.509 extensions to certificate OpenSSL](https://www.golinuxcloud.com/add-x509-extensions-to-certificate-openssl/)
[config - OpenSSL CONF library configuration files](https://www.openssl.org/docs/man1.1.1/man5/config.html)
[How Frequently Should You Rotate PKI Certificates and Keys?](https://www.venafi.com/blog/how-frequently-should-you-rotate-pki-certificates-and-keys)
[self-signed-certificate-with-custom-ca.md] https://gist.github.com/fntlnz/cf14feb5a46b2eda428e000157447309) good stuff in the comments, but mostly for Linux
[penSSL CONF library configuration files](https://www.mkssoftware.com/docs/man5/openssl_config.5.asp)
[How to setup your own CA with OpenSSL](https://gist.github.com/Soarez/9688998)
[OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/index.html)
[OpenSSL Cheat Sheet by albertx](https://cheatography.com/albertx/cheat-sheets/openssl/)
[Creating a Self-Signed Certificate With OpenSSL](https://www.baeldung.com/openssl-self-signed-cert) extfile example

### Code Signing Certificates

\

## Store the Root Certificate Authority in a Secret Management Secure Vault

To sign a CSR for an intermediate CA requires a Trusted Root CA. The CA must be installed to the machine where the signing steps will be run. The signing steps expect a specific directory structure for the Root Ca to work. The location of the three CA files, and the root of the directory structure, can vary as required by the organization. The location of these paths should be subject to 'least privilege'. The ATAP Utilities module uses ACL permissions to restrict access to these locations, and uses a SecretVault to store the current locations of the files and subdirectory

To sign things with the CA Certificate requires three things: The path to the CA Certificate, the path to the Private and Public Key Pair, and the path to the Encryption Key PassPhrase file. There may be multiple CA Certificates in an organization. At the least there will be Development, Testing, and Production versions. CA Certificates need to be rotated, as well. Each CA Certificate used in an organization will have it's own Secret Vault. Access to the specific Secret Vault will be controlled by a Role permission, in keeping with the Least Privilege principle. One role will allow for Read/Write access, the other Role will allow only for Read Access.

see [cxref] for instructions on creating and using the Powershell Secret Vaults

```Powershell
Store-CertificateInVault {()
  $VaultName = Get-VaultExtensionName -Purpose 'RootCA' -Subject -SubjectAlternativeName -Environment $global:settings  [$global:configRootKeys['EnvironmentConfigRootKey']]
  Get-UsersSecretStoreInfo
  Unlock-UsersSecretStore
  Test-SecretVault
  if (Get-Secret CertificatePath) {Remove-Secret CertificatePath}
  if (Get-Secret PublicPrivateKeyPath) {Remove-Secret PublicPrivateKeyPath}
  if (Get-Secret EncryptionKeyPassPhrasePath) {Remove-Secret EncryptionKeyPassPhrasePath}
  Set-Secret CertificatePath
  Set-Secret PublicPrivateKeyPath
  Set-Secret EncryptionKeyPassPhrasePath
}
```

## Deployment Credentials

### MyGet Credentials

### Public Nuget Server Credentials

### Private Nuget Server Credentials

### Public Chocolatey Server Credentials

### Private Chocolatey Server Credentials

### Public PowershellGallery Server Credentials

### Private PowershellGallery Server Credentials

### Cloud Asset Storage Applications

#### ImageKit.io Credentials

#### Dropbox Development Token

## Secret Management

ATAP.Utilities.Security.Powershell

- Add-UserSecretStore
- Get-UserSecretStoreInfo
- Unlock-UserSecretStore

`$global:SecurityAndSecrets.ps1`

## Secrets Used in the Development Process

### Secrets for the Development Database

## Secrets Used in the Testing Process

## Secrets Used in the Documentation Process

## Secrets Used in the Packaging Process

## Secrets Used in the Deployment Process

### Secrets needed to deploy to any of the 'WebServerDropsBaseURLConfigRootKey' = 'FileSystemDropsBasePath'

## Secrets used by the CI/CD pipeline

## Secrets for 3rd Party Tools

### BeyondCompare License

### ServiceStack License

#### settings.json

### Visual Studio Code Extensions

#### Git

Store the remote repository URL and credentialal
