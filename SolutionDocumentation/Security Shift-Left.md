# Security in the Libraries, Packages and CI/CD pipeline

If you are viewing this `Security Shift-Left.md` file in GitHub, here is this same [Security Shift-Left](http://nope.com/nope.html) on the documentation site.

## <a id="Introduction" />Introduction

Security is everyone's business in software development. The applications and libraries being developed as 'product' should have security as a first-class citizen. Automated scanning tools should, during the build, inspect and analyze the code being developed for known security flaws and best practices. The 3rd-party SW being used in the product (the items in the Software Bill of Materials (SWBOM)) should report their compliance with security best practices, and these 3rd party softwares and their security score should made available in the build artifacts included in the 'product' packages.

There are multiple security concerns in an organizations. This document is going to focus on securing the 'secrets' that are used in the Development and CI/CD process to produce an application. ToDo: Add a reference to another document that focuses on securing user information within a generated application.

Every organization has "secrets" that are used in the Development and CI/CD processes. These secrets must be protected, because they are often linked to 3rd-party software that costs money to execute. Loss and then misuse of the secrets could cost an organization a lot of money.

The CI/CD pipeline will need access to "secrets" that authorize access to certain sensitive information. For example, credentials to access Git, credentials to access cloud storage locations, Code Signing Certificates, SHA generation, database credentials, passwords for service accounts, oAuth credentials, API access tokens, all need to be secured and protected from disclosure.

The deployment servers to which 'product' is deployed are usually protected by credentials to ensure only authorized production packages are deployed.

The developer's machines all need individual security to handle user and Service passwords, authorization tokens from cloud services,

Securing secrets used in the development process, the CI/CD tools, and the final production products is a difficult tricky task, and there are a lot of ways to go about it. The ATAP.Utilities use a three-stage mechanism.

## <a id="Overview" />Overview

An organization needs a secrets vault strategy and a Public Key Infrastructure (PKI) strategy.

### PKI

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

Note: `OPENSSL_HOME`, `OPENSSL_CONF`, and `RANDFILE` were removed from the global HostSettings/profile environment. Exporting them globally breaks tools that inherit the process environment but bundle their own TLS runtime, including the Bitwarden `bw` CLI. When the self-signing and internal CA work resumes, set these values explicitly in the script or shell immediately before calling OpenSSL utilities, then clear or restore them afterward.

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

All secrets are stored in plaintext in a subdirectory rooted at DisasterRecoveryPath and also in another subdirectory rooted at DisasterRecoveryBackup path. These actual locations are whatever locations the organizations feel is their most secure storage.

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
*** EncryptedPasswordFiles
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
    #keyUsage                               = @('critical', 'cRLSign', 'digitalSignature', 'keyCertSign')
    #ExtendedkeyUsage                       = 'CA:TRUE'
    # ExtendedkeyUsage= @('critical','codeSigning')
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

- Create WSMan SSL Certificate(s) (ServerAuth) for all computers in the organization's workgroup

  - Define a DistinguishedNameHash for the WSMan SSL Certificate Request for each computer
  - Create an EncryptionPassPhrase file
  - Create an EncryptedKey file
  - Create a WSMan SSL Certificate Request
  - Create a signed WSMan SSL Certificate
  - Copy the signed WSMan SSL Certificate from the signing certificate's directory structure to the organization's directory structure (vault)

- Create SSL Server Certificate(s) for all computers in the organization's workgroup
  - Define a DistinguishedNameHash for the SSL Server Certificate Request for each computer
  - Create an EncryptionPassPhrase file
  - Create an EncryptedKey file
  - Create a SSL Server Certificate Request
  - Create a signed SSL Server Certificate
  - Copy the signed SSL Server Certificate from the signing certificate's directory structure to the organization's directory structure (vault)

The following steps must be taken manually by a security administrator on any computer that does not have PSRemoting enabled

- Deploy the Root CA to each computer in the workgroup (or each new host as it is added)
- Deploy the appropriate WSMan SSL certificate to each computer in the organization's workgroup (or each new host as it is added))

##### Validating needed Tools, Environment variables and Directory Structure

The script `ValidatePKIPrerequisites.ps1` can be run on any machine to determine if all of the PKI prerequisites are met.

##### Define a DistinguishedNameHash for the Root Certificate Authority (CA) of the organization

The Root CA should have just a CN and an Organization, and they should be the same string

##### Root Certificate Authority (CA) Certificate

Every organization needs a Root CA Certificate, to sign internal Certificates. The Root CA Certificate should be used to sign Intermediate Signing Certificates, and nothing else. Creation of a Root CA Certificate requires a PassPhrase File, an EncryptedeKeyFile, and an openSSL Configuration file.

###### Create an Encryption Key PassPhrase File

```Powershell
  $EncryptionKeyPassPhrasePath =  Get-DistinguishedNameQualifiedFilePath -DistinguishedNameHash $DNHash -BaseFileName $global:settings[$global:configRootKeys['SecureCertificatesCAPassPhraseFileBaseFileNameConfigRootKey'] -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesEncryptionPassPhraseFilesPathConfigRootKey']]
  New-RandomPassPhraseToFile -PassPhrasePath $EncryptionKeyPassPhrasePath
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

There are a few settings needed to sign a Certificate with a CA, that cannot be modified / set on the command line. These few settings MUST be configured in the OpenSSL configuration file. Luckily, they can be done with environment variables

OPENSSL_SIGNINGCERTIFICATES_DIR
dir = C:/Dropbox/Security/Certificates/SigningCertificates/Root # Where everything is kept
#private_key = $dir/PrivateKeys/cakey.pem # The private key
serial = $dir/serial # The current serial number
database = $dir/CertificatesIssued.txt # database index file.
new_certs_dir = $dir/NewCertificates # default place for new certs.
certs = $dir/Certificates # Where the issued certs are kept
#crl = $dir/crl.pem # The current CRL
#crl_dir = $dir/crl # Where the issued crl are kept

##### Install the Root Certificate Authority Certificate

Add the new Root Certificate Authority certificate to all machines in the workgroup

Note that PSRemoting depends on having a trusted SSL certificate for this purpose.
Trusting an internally generated SSL certificate requires an internal Root Certificate Authority certificate
Therefore PSRemoting cannot be used to install an internal Root Certificate Authority certificate on a machine which does not yet have PSRemoting working

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
  ToDO: Powershell way - (Need to figure out the proper cert store)
  ToDo: The following command did not install the cert, it just brought up the manual interactive certmgr widget

`CertMgr /add $CertificatePath /s /r localMachine root `

- \*nix
- MacOS
- IOS
- Android

#### Intermediate Certificate Authority Certificates

##### Create an SSL Server Certificate

There are many scenarios that require a trusted SSL Certificate to authenticate a specific server. The examples below will create a SSL certificate for a server DN. Among other things, it can be used to support PSRemoting in a workgroup environment.

Certificate creation starts with the DistinguishedNameHash # Subject, SubjectAlternativeName, and the type of certificate (template)
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
New-RandomPassPhraseToFile -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath
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

```Powershell
$CertificatePath = Get-DistinguishedNameQualifiedFilePath  -BaseFileName 'SSLCertificate.crt' -OutDirectory $global:settings[$global:configRootKeys['SecureCertificatesCertificatesPathConfigRootKey']]
$ValidityDays = 3650
Create-CertificateAndSign -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -CertificateRequestPath $CertificateRequestPath -validityDays $validityDays -CertificatePath $CertificatePath -CACertificatePath $CACertificateInfo.CertificatePath -CAEncryptedPrivateKeyPath $CACertificateInfo.EncryptedPrivateKeyPath -CAEncryptionKeyPassPhrasePath $CACertificateInfo.EncryptionKeyPassPhrasePath
$WinRMSSLCertificatePath -days 3650

```

#### Save the SSL Certificate into a Vault

Use a specific vault for least privilege

Keep the following until testing proves them unnecessary (are the RootCA Cert and the SSL cert private/public key pairs the same? what's the "best" way to generate the PP Key pair)

##### Create a private/public key pair for the SSL certificate

```Powershell
$WinRMSSLPrivateKeyPath = 'C:\Dropbox\SecretManagement\CARoot\PrivateKeys\WinRMSSLKey.private'
$WinRMSSLPrivateKeyPassphraseFilePath = join-path $global:settings[$global:ConfigRootkeys['SecureTemporaryDirectoryConfigrootKey']] 'WinRMSSLPrivateKeyPassphrase.txt'
# ToDo: make up a random passphrase and save it to a secret vault? Also plaintext backup for disaster recovery, only to USB. The write it to the temporary directory
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

Combine the certificate and the key into a .pfx file

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
[openSSL CONF library configuration files](https://www.mkssoftware.com/docs/man5/openssl_config.5.asp)
[How to setup your own CA with OpenSSL](https://gist.github.com/Soarez/9688998)
[OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/index.html)
[OpenSSL Cheat Sheet by albertx](https://cheatography.com/albertx/cheat-sheets/openssl/)
[Creating a Self-Signed Certificate With OpenSSL](https://www.baeldung.com/openssl-self-signed-cert) extfile example
[Advanced PKI](https://pki-tutorial.readthedocs.io/en/latest/advanced/index.html)
[ExtendedKeyUsage](https://ldapwiki.com/wiki/ExtendedKeyUsage)
[https://www.golinuxcloud.com/add-x509-extensions-to-certificate-openssl/](How to add X.509 extensions to certificate OpenSSL)

### Code Signing Certificates

\

## Store the Root Certificate Authority in a Secret Management Secure Vault

To sign a CSR for an intermediate CA requires a Trusted Root CA. The CA must be installed to the machine where the signing steps will be run. The signing steps expect a specific directory structure for the Root Ca to work. The location of the three CA files, and the root of the directory structure, can vary as required by the organization. The location of these paths should be subject to 'least privilege'. The ATAP Utilities module uses ACL permissions to restrict access to these locations, and uses a SecretVault to store the current locations of the files and subdirectory

To sign things with the CA Certificate requires three things: The path to the CA Certificate, the path to the Private and Public Key Pair, and the path to the Encryption Key PassPhrase file. There may be multiple CA Certificates in an organization. At the least there will be Development, Testing, and Production versions. CA Certificates need to be rotated, as well. Each CA Certificate used in an organization will have it's own Secret Vault. Access to the specific Secret Vault will be controlled by a Role permission, in keeping with the Least Privilege principle. One role will allow for Read/Write access, the other Role will allow only for Read Access.

see [cxref] for instructions on creating and using the Powershell Secret Vaults

```Powershell
Store-CertificateInVault {()
  $VaultName = Get-VaultExtensionName -Purpose 'RootCA' -Subject -SubjectAlternativeName -Environment $global:settings  [$global:configRootKeys['EnvironmentConfigRootKey']]
  Get-UsersSecretVaultInfo |  Unlock-UsersSecretVault -passThru
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

### Setting up the SecretManagement and Bitwarden

Using Microsoft.PowerShell.SecretManagement with Bitwarden
To retrieve secrets from Bitwarden using the Microsoft.PowerShell.SecretManagement module, follow these steps:

Step-by-Step Guide

1. Install Required Modules

```Powershell
# Install SecretManagement module
Install-Module -Name Microsoft.PowerShell.SecretManagement -Repository PSGallery -Scope AllUsers
# Install the Bitwarden SecretManagement extension vault
Install-Module -Name SecretManagement.BitWarden -Repository PSGallery -Scope AllUsers
```

1. Register the Bitwarden Vault

```Powershell
# Register the Bitwarden vault with SecretManagement
# The vault name can be anything you choose
Register-SecretVault -Name 'BitwardenVault' -ModuleName 'SecretManagement.BitWarden' -DefaultVault

# Verify the vault is registered
Get-SecretVault
```

1. Authenticate with Bitwarden
   Before you can retrieve secrets, you need to unlock your Bitwarden vault:

````Powershell
# Unlock the vault (you'll be prompted for your master password)
Unlock-SecretVault -Name 'BitwardenVault'

# Or use the Bitwarden CLI to login first
bw login
bw unlock
```

1. Retrieve Secrets from Bitwarden

```Powershell
# Get a secret by name
$secret = Get-Secret -Name 'MySecretName' -Vault 'BitwardenVault'

# Get a secret as plain text (use with caution)
$secretPlainText = Get-Secret -Name 'MySecretName' -Vault 'BitwardenVault' -AsPlainText

# List all secrets in the vault
Get-SecretInfo -Vault 'BitwardenVault'

# Get a specific credential (username/password pair)
$credential = Get-Secret -Name 'MyLoginItem' -Vault 'BitwardenVault'
Write-Host "Username: $($credential.UserName)"
Write-Host "Password: $($credential.GetNetworkCredential().Password)"
```

1. Example Integration with ATAP.Utilities Functions

Heres how to integrate this into an ATAP.Utilities function:
Important Notes
Bitwarden CLI Required: The SecretManagement.BitWarden extension requires the Bitwarden CLI (bw) to be installed and in your PATH.

Session Management: The Bitwarden vault must be unlocked before retrieving secrets. The session expires after a period of inactivity.

Secret Types: Bitwarden stores different types of items:

Login items (username/password) → returned as PSCredential
Secure notes → returned as SecureString or plain text
Identity items → returned with multiple fields
Alternative: Direct Bitwarden CLI: If you need more control, you can use the Bitwarden CLI directly instead of SecretManagement:

```Powershell
# Login and unlock
bw login
$sessionKey = bw unlock --raw

# Set session key as environment variable
$env:BW_SESSION = $sessionKey

# Get a secret
$secret = bw get password "MySecretName" | ConvertTo-SecureString -AsPlainText -Force

# Or get full item details as JSON
$item = bw get item "MySecretName" | ConvertFrom-Json
```

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

Store the remote repository URL and credentials

## Using Wireshark with SSL

```Powershell
# Capture SSL keys needed to decrypt SSL traffic using wireshark, to do this manually, it requires elevated permission
# use sparingly, because this file gets locked and won't sync with Dropbox
[Environment]::SetEnvironmentVariable( 'SSLKEYLOGFILE', '"C:\Dropbox\Security\SSLKeyLogFile.txt"', 'Machine' )
````

---

## Bitwarden Session Bootstrap

<!-- Philote: e1304e80-8720-4212-b842-b7c17d3f100d -->

### Problem

The Bitwarden desktop application does **not** write a `BW_SESSION` environment variable
into the Windows session on login. `BW_SESSION` must be acquired explicitly at the start
of each PowerShell session.

### Rules

**BSB-1** — Acquire `BW_SESSION` once per shell session:

```powershell
$env:BW_SESSION = bw unlock --passwordenv BW_PASSWORD --raw
```

Run this in your PowerShell profile (`Microsoft.PowerShell_profile.ps1`) so every new
terminal automatically unlocks the vault.

**BSB-2** — `BW_PASSWORD` must not be stored in plain-text files or committed to source
control. Store it in Windows Credential Manager or in a securely permissioned startup
script readable only by the current user.

**BSB-3** — VS Code terminals inherit `BW_SESSION` **only** if VS Code was launched from
a shell where `BW_SESSION` was already set. If you open VS Code from the Start menu after
your profile has run, the VS Code process will have the env var; if you open it from a
fresh shell that has not yet run the unlock, it will not.

**BSB-4** — `BW_SESSION` is valid only for the lifetime of the terminal/shell session.
Do **not** persist it to a file, write it to the registry, or export it to
`[System.Environment]::SetEnvironmentVariable` at Machine scope. Invalidate it explicitly
with `bw lock` when the session is done if desired.

### Recommended profile pattern

```powershell
# In Microsoft.PowerShell_profile.ps1
if ($env:BW_PASSWORD) {
    $env:BW_SESSION = bw unlock --passwordenv BW_PASSWORD --raw
}
```

This guard prevents the unlock attempt when `BW_PASSWORD` is absent (e.g., on CI agents
that use the API-key flow instead — see §Service Accounts / CI below).

---

## Known Issues: Bitwarden SecretManagement Extension

<!-- Philote: 8e7bb62c-099e-47ae-aabf-82e2a6fe8b6f -->

### Issue: `match`-property null-cast error

**Affected modules:** `SecretManagement.BitWarden` and `SecretManagement.Warden`

**Symptom:**

```
Failed to retrieve secret from Bitwarden. Exception: Exception setting "match":
"The property 'match' cannot be found on this object. Verify that the property
exists and can be set."
```

**Root cause:** Inside the extension, the code iterates over every `login.uri` object
and unconditionally casts its `match` property:

```powershell
$_.login.uris.ForEach({ [BitwardenUriMatchType]$_.match = [int]$_.match })
```

When a URI object has no `match` field (e.g., a simple string URI added without a
match type in the Bitwarden UI, or a CLI output shape change), PowerShell throws the
error above. The bug is in the extension code; the vault item definition is not at fault.

**Workaround — null-guard patch:**

Locate the offending line in the installed module and wrap it:

```powershell
$_.login.uris.ForEach({
    if ($_.PSObject.Properties['match']) {
        [BitwardenUriMatchType]$_.match = [int]$_.match
    }
})
```

**Preferred workaround (avoid the extension entirely):** Call `bw` directly:

```powershell
$secret = bw get password 'my-secret-name' --session $env:BW_SESSION
```

This bypasses the extension JSON-handling layer. Use this approach until upstream
modules publish a patched release.

**Cross-references:** `SecretsPluginArchitecture.md`, `Module Catalog.md` §3.3.9

---

## Service Accounts / CI

<!-- Philote: 5ed118cb-1711-4ea2-b32f-1cb9184baa05 -->

### Principle

CI/CD pipelines must **never** use an interactive `bw login` flow. Use the Bitwarden
API-key authentication path so the vault can be unlocked non-interactively inside a
headless service process (Jenkins agent, Windows service, GitHub Actions runner, etc.).

### Setup — Bitwarden side

1. Create a **dedicated Bitwarden service account** (a separate Bitwarden account or an
   Organisation member with collection-scoped access limited to CI secrets).
2. In the Bitwarden web vault, navigate to **Settings → Security → API Key** and generate
   an API key. Record `client_id` and `client_secret`.

### Setup — machine / agent side

Store the following as **machine-scope** (or service-account-user-scope) Windows
environment variables — **not** as plain-text files or in source code:

| Variable | Contents |
| -------- | -------- |
| `BW_CLIENTID` | `client_id` from Bitwarden API Key screen |
| `BW_CLIENTSECRET` | `client_secret` from Bitwarden API Key screen |
| `BW_PASSWORD` | Master password of the CI service account |

Provision these before installing the Jenkins service (or before starting the agent).
See `NewComputerSetup.md` § Jenkins bootstrap.

### Runtime unlock sequence

```powershell
# Run once during agent/service startup, before any secret reads
bw login --apikey   # reads BW_CLIENTID / BW_CLIENTSECRET from env
$env:BW_SESSION = bw unlock --passwordenv BW_PASSWORD --raw
```

Check-before-login guard:

```powershell
if (-not (bw status | Select-String '"status":"unlocked"')) {
    bw login --apikey
}
$env:BW_SESSION = bw unlock --passwordenv BW_PASSWORD --raw
```

Retrieve a secret in a pipeline step:

```powershell
$secret = bw get password 'my-secret-name' --session $env:BW_SESSION
```

### Security practices

- **Separate vault / org:** grant the CI account access only to the collection(s) it needs.
- **Never write `BW_SESSION` to disk:** keep it only in the process environment.
- **Rotate API keys** on the same schedule as other CI service credentials.
- **`BW_PASSWORD` in Jenkins credentials store:** inject it as an environment variable
  per job; do not bake it into node configuration or service wrapper scripts.
- At job end, call `bw lock` to invalidate the session token for the process lifetime.

## PSResourceGet Credential-at-Rest: Register-PSResourceRepository -CredentialInfo

<!-- Philote: dda5026c-aefd-481f-9927-fb2b16618339 -->

**Rule CIR-1 — Never store credentials in plain text when registering a repository.**
Do not embed passwords, PATs, or API keys in `$PROFILE`, in `PSRepositories.xml`, or
as inline `-Credential` arguments. Both locations are world-readable by any process
running as the same user.

**Rule CIR-2 — Use `-CredentialInfo` with a SecretManagement vault.**
PSResourceGet v3 (`Microsoft.PowerShell.PSResourceGet`) supports a `-CredentialInfo`
parameter on `Register-PSResourceRepository`. A `PSCredentialInfo` object binds the
registration to a named vault + secret name. PSResourceGet re-fetches the credential
from the vault on each operation — no plain-text credential is stored in the repository
registration.

```powershell
# 1. Store the PAT/password in a SecretManagement vault once
Set-Secret -Name 'ProGetPAT' -Vault 'SecretStore' -Secret '<your-PAT>'

# 2. Create a PSCredentialInfo object referencing vault + secret name
$credInfo = [Microsoft.PowerShell.PSResourceGet.UtilClasses.PSCredentialInfo]::new(
    'SecretStore', 'ProGetPAT'
)

# 3. Register the feed — credential is never encoded into PSRepositories.xml
Register-PSResourceRepository `
    -Name    'ProGet' `
    -Uri     'http://proget.local:8624/nuget/PowerShell/v3/index.json' `
    -Trusted `
    -CredentialInfo $credInfo
```

**Rule CIR-3 — This replaces the legacy `-Credential` inline pattern.**
The old `Register-PSRepository` (PowerShellGet v2) accepted `-Credential [PSCredential]`
directly, which required the caller to resolve the secret first and pass it as a live
object. With `-CredentialInfo`, binding is deferred to call time by the PSResourceGet
runtime — the resolved secret is never captured in a variable in your profile.

**Rule CIR-4 — Vault must be unlocked before any PSResourceGet command.**
If the vault (e.g. `SecretStore` with a vault password) is not unlocked,
PSResourceGet will throw a credential-resolution error. Ensure the vault is unlocked in
the same session before calling `Find-PSResource`, `Install-PSResource`, or
`Publish-PSResource` against a private feed.

> **Cross-reference:** `NewComputerSetup.md` — ProGet feed registration step.
> Use this pattern whenever adding a private ProGet or Azure Artifacts feed during
> workstation setup.

### Summary

| Approach | Credential stored in | Safe? |
|---|---|---|
| `-Credential (Get-StoredCredential)` inline | memory (temporary) | risky if logged |
| `-Credential` in `$PROFILE` | plain-text profile file | **NO** |
| `PSRepositories.xml` XML-encoded | registry / AppData XML | **NO** |
| `-CredentialInfo` (PSResourceGet v3) | SecretManagement vault | **YES** |

**Source:** `AI on VSC and Powershell and Repository Feeds.md` §4 Private feeds
(lines 314–321, 340).

---

## API Key Rotation Incidents

_Migrated from `_Planning/Explainers/0004-BuildMaster-Setup.md` lines 26-80. Each incident establishes a precedent / mandate for future API key handling._

### INC-001 — BuildMaster API Key Rotation (2026-03-25, SC-0044 + SEC-01)

**Severity:** High — API key value was exposed in BuildMaster debug execution logs and
potentially visible to anyone with access to the BuildMaster web UI.

**Root cause:** The OtterScript Build plan passed the ProGet API key directly as a
`dotnet nuget push --api-key` argument without masking. BuildMaster's Debug log level
captures full command arguments, so the key value appeared in plaintext in every build's
execution log.

**Contributing factor:** The Bitwarden entry was named `ProGet-BuildMaster-API-Key`
(hyphen-separated), inconsistent with the current dotted SecretName convention.
The env var was `PROGET_BUILDMASTER_KEY`, also inconsistent — it lacked the
`_API_` infix that indicates an API key.

**Actions taken:**

1. Generated a new BuildMaster API key in **Administration → API Keys & Access Logs**
2. Disabled the compromised key in the same UI
3. Renamed the Bitwarden entry to `ProGet.BuildMaster.API.Key` and updated the stored key value
4. Renamed the environment variable to `PROGET_BUILDMASTER_API_KEY` throughout all repos
5. Updated the OtterScript Build plan to wrap the key with `$Obscure(...)`:

   ```otterscript
   set $MaskedApiKey = $Obscure($EnvironmentVariable(PROGET_BUILDMASTER_API_KEY));
   ```

   `$Obscure()` redacts the value in **all** BuildMaster log levels including Debug,
   before it reaches the `dotnet nuget push` argument string.

6. Eliminated hardcoded sprint-branch paths in the script via an Application Variable.

**Verification:** New key works for pushes to `nuget-experimental`; debug logs no longer
contain the key value; old key disabled (returns 403).

### Precedents / Mandates From INC-001

These rules are now project policy, derived from the actions above:

1. **API-key Bitwarden SecretNames** use dotted notation such as
   `ProGet.BuildMaster.API.Key`. Environment variables, when an integration truly
   requires them, remain `ALL_UPPERCASE_WITH_UNDERSCORES`.
2. **All OtterScript plans MUST** use `$Obscure(...)` when reading secrets from
   environment variables before passing them as command arguments. Forgetting `$Obscure()`
   is a recurrence of INC-001.

---

## Secret Naming Convention

_Migrated from `_Planning/Explainers/0020-bitwarden-naming-convention.md`. Authoritative for `New-SprintBitwardenSecrets`, `Remove-SprintBitwardenSecrets`, `New-PermanentBitwardenSecrets`, and `Get-BitwardenSecret`._

### Per-Sprint Secrets

```text
dbConnectionString.<Database>.<Host>.<Tier>.<DeveloperUsername>
```

| Field                 | Values                                          |
|-----------------------|-------------------------------------------------|
| `<Database>`          | `master`, `ATAPUtilities`, `AceCommander`       |
| `<Host>`              | `$env:COMPUTERNAME` or `localhost`              |
| `<Tier>`              | `Dev` or `Exp`                                  |
| `<DeveloperUsername>` | Windows username (e.g. `whertzing`)             |

**12 secrets per developer per sprint** (3 databases × 2 hosts × 2 tiers).

Example: `dbConnectionString.ATAPUtilities.UTAT022.Dev.whertzing`,
`dbConnectionString.AceCommander.localhost.Exp.whertzing`, etc.

### Permanent Secrets

```text
dbConnectionString.<Database>.<Host>.<Tier>
```

No `<DeveloperUsername>` suffix.

| Field        | Values                                         |
|--------------|------------------------------------------------|
| `<Database>` | `ATAPUtilities`, `AceCommander`                |
| `<Host>`     | Dedicated ecosystem server (default `utat022`) |
| `<Tier>`     | `Integration`, `QA`, `Production`              |

**6 secrets per workstation** (2 databases × 3 tiers).

Examples: `dbConnectionString.ATAPUtilities.utat022.Production`,
`dbConnectionString.AceCommander.utat022.Integration`.

### Connection String Format

Per-sprint:

```text
Server=<Host>\<Tier><DeveloperUsername>;Database=<Database>;Integrated Security=True;MultipleActiveResultSets=True;TrustServerCertificate=True;
```

Permanent:

```text
Server=<Host>\<Tier>;Database=<Database>;Integrated Security=True;MultipleActiveResultSets=True;Application Name=<Database>-<Tier>;TrustServerCertificate=True;
```

### Lifecycle Cmdlets

| Category   | Created by                      | Removed by                        | When                           |
|------------|---------------------------------|-----------------------------------|--------------------------------|
| Per-sprint | `New-SprintBitwardenSecrets`    | `Remove-SprintBitwardenSecrets`   | Sprint start / sprint end      |
| Permanent  | `New-PermanentBitwardenSecrets` | Manual (never automatically)      | Developer onboarding (once)    |

Both creation/deletion cmdlets run `bw sync` automatically to flush the CLI cache.
`Get-BitwardenSecret` reads `BW_SESSION` from User-scope registry if process-scope
is absent (R-10 pattern).
