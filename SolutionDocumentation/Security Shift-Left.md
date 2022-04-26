# Security in the Libraries, Packages and CI/CD pipeline

If you are viewing this `Security Shift-Left.md` in GitHub, [here is this same Security Shift-Left on the documentation site]()

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

Certificate creation starts with the Subject, SubjectAlternativeName, and the type of certificate (template)
[Distinguished Names](https://ldapwiki.com/wiki/Distinguished%20Names)

Example:

```Powershell
$Subject = @{
CN='utat022'
Country='US'
StateOrTerritory='UT'
Organization='ATAPUtilities.org'
OrganizationUnit='Development'
SubjectReplacementPattern = 'CN="{0}",OU="{1}",O="{2}",ST="{4},C="{3}"'
} | Get-Subject  # return $SubjectReplacementPattern -f $CN, $OrganizationUnit, $Organization, $StateOrTerritory, $Country

$SubjectAlternativeName = @{
Email= 'SecurityAdminsList@ATAPUtilities.org'
SubjectAlternativeNameReplacementPattern = 'E="{0}"'
} | Get-SubjectAlternativeName # return $SubjectAlternativeNameReplacementPattern -f $EMail


$CertificateRequestConfigPath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestConfigsPathConfigRootKey']]'RootCertificateAuthorityCertificateRequestTemplate.txt'

#return $global:settings[$global:configRootKeys['CertificateSecurityDNFilePathReplacementPatternConfigRootKey']] -f $Subject.CN $BaseFileName

```

#### Root Certificate Authority Certificate

Three of these for an organization; Development, Testing, and Production

##### Create an Encryption Key PassPhrase File for the RootCertificateAuthorityCertificate Private and Public Key Pair

```Powershell
$EncryptionKeyPassPhrasePath = Get-CertificateSecurityDNFilePath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -BaseFileName 'RootCertificateAuthorityCertificatePassPhraseFile.txt' -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']]
New-EncryptionKeyPassPhraseFile -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath
```

##### Create an RootCertificateAuthorityCertificate Private and Public Key Pair

```powershell
# Out filename template using Subject and SubjectAlternativeName
$EncryptedPrivateKeyPath = Get-CertificateSecurityDNFilePath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -BaseFileName 'RootCertificateAuthorityCertificateEncryptedPrivateKey.pem' -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']]
New-EncryptedPrivateKey -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath  -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath  -KeySize $KeySize
# generate a private key using maximum key size of $KeySize
# key sizes can be 512, 758, 1024, 1536 or 2048.
openssl genrsa -des3 -passout file:$EncryptionKeyPassPhrasePath -pubout -outform PEM -out $EncryptedPrivateKeyPath $KeySize
# using the -des3 option encrypts the private key, and requires a password.
# putting the password on the command line with -passout pass:abcd1234 is insecure, as command line arguments are visible to any onther process
#  A better solution to providing a password is to use the password to populate a temporary file in a secure location
#  and use -passout file:passphrase.txt
# openssl genrsa -des3 -out $RootCertificateAuthorityCertificatePrivateKeyPath $KeySize
# openssl genrsa -des3 -passout file:$EncryptionKeyPassPhrasePath -pubout -outform PEM -out $EncryptedPrivateKeyPath $KeySize

# openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out $WinRMSSLPrivateKeyPath

```

No Longer needed?
    Generate the public key from the private key

    ```Powershell
    # generate a public key using the private key
    $RootCertificateAuthorityCertificatePublicKeyPath = 'C:\Dropbox\SecretManagement\CARoot\PublicKeys\RootCertificateAuthorityCertificateKey.public'
    openssl rsa -in $RootCertificateAuthorityCertificatePrivateKeyPath -out $RootCertificateAuthorityCertificatePublicKeyPath -pubout -outform PEM
    ```

##### Generate the Root Certificate Authority Certificate Request

```Powershell
$CertificateRequestPath = Get-CertificateSecurityDNFilePath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -BaseFileName 'RootCertificateAuthorityCertificateRequest.csr' -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestsPathConfigRootKey']]
Create-CertificateRequest -Template $CertificateRequestConfigPath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -CertificateRequestPath $CertificateRequestPath
```

##### Generate the Root Certificate Authority Certificate

Example

```Powershell
$CertificatePath = Get-CertificateSecurityDNFilePath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -BaseFileName 'RootCertificateAuthorityCertificate.crt' -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']]
$ValidityDays = 3650
Create-Certificate -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -CertificateRequestPath $CertificateRequestPath  -validityDays $validityDays -CertificatePath $CertificatePath
# openssl req -x509 -in $CertificateRequestPath -des3 -key $EncryptedPrivateKeyPath -passout file:$EncryptionKeyPassPhrasePath -sha256 -days $validityDays -out ```
# openssl req -x509 -new -nodes -key $RootCertificateAuthorityCertificatePrivateKeyPath -sha256 -days 1825 -out $RootCertificateAuthorityCertificatePath
# openssl req -x509 -new -key $RootCertificateAuthorityCertificatePrivateKeyPath -des3 -passout file:passphrase.txt -sha256 -days $validityDays -out
```

##### Store the Root Certificate Authority in a Secret Management Secure Vault

To sign things with the CA Certificate requires three things: The path to the CA Certificate, the path to the Private and Public Key Pair, and the path to the Encryption Key PassPhrase file. There may be multiple CA Certificates in an organization. At the least there will be Development, testing, and Production versions. CA Certificates need to be rotated, as well. Each CA Certificate used in an organization will have it's onw Secret Vault. Access to the specific  Secret Vault will be controlled by a Role permission, in keeping with the Least Privilege principle. One role will allow for Read/Write access, the other Role will allow only for Read Access.

Vault naming scheme (KeePass and SecretStore)
`{host}_{CertificatePurpose}[_{Environment}]` the optional _{Environment} is omitted for production values

see [cxref] for instructions on creating and using the Powershell Secret Vaults

Example

```Powershell
Store-CertificateInVault {()
  $VaultName = Get-VaultExtensionName -Purpose 'RootCertificateAuthorityCertificate' -Subject -SubjectAlternativeName -Environment $global:settings  [$global:configRootKeys['EnvironmentConfigRootKey']]
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

##### Install the Root Certificate Authority Certificate

Add the new Root Certificate Authority certificate to all machines in the workgroup

Note that powershell remoting depends on having a trusted SSL certificate for this purpose.
Trusting an internally generated SSL certificate requires an internal Root Certificate Authority certificate
Therefore Powershell remoting cannot be used to install an internal Root Certificate Authority certificate on a machine which does not yet have PS-remoting working

Repeat the following commands on each machine on the workgroup, as an administrator

- Windows

   ```Powershell
   $RootCertificateAuthorityCertificateCertStoreLocation = 'cert:\LocalMachine\CA'
  Import-Certificate -FilePath $CertificatePath -CertStoreLocation $RootCertificateAuthorityCertificateCertStoreLocation
  ```

- *nix
  ToDo:  Validate that the Root Certificate Authority Certificate has been installed on *nix
- MacOS
  ToDo:  Validate that the Root Certificate Authority Certificate has been installed on MacOS
- IOS
  ToDo:  Validate that the Root Certificate Authority Certificate has been installed on IOS
- Android
  ToDo:  Validate that the Root Certificate Authority Certificate has been installed on Android


##### Validate that the Root Certificate Authority Certificate has been installed

Example

- Windows

  ```powershell
  (ls $RootCertificateAuthorityCertificateCertStoreLocation).subject | Where-Object{$_ -match "CN=""$Subject.CN""}
  ```

- *nix
  ToDo:  Validate that the Root Certificate Authority Certificate has been installed on *nix
- MacOS
  ToDo:  Validate that the Root Certificate Authority Certificate has been installed on MacOS
- IOS
  ToDo:  Validate that the Root Certificate Authority Certificate has been installed on IOS
- Android
  ToDo:  Validate that the Root Certificate Authority Certificate has been installed on Android

##### Add the Root Certificate Authority Certificate to the Trusted Roots

Example

- Windows
   See [Create Your Own SSL Certificate Authority for Local HTTPS Development](https://deliciousbrains.com/ssl-certificate-authority-for-local-https-development/) for instructions using the MMC snap-in
  ToDO: Powershell way - (Need to figure out teh proper cert store)

- *nix
- MacOS
- IOS
- Andriod


#### Create an SSL Certificate

There are many scenarios that require a trusted SSL certificate. The examples below will create a SSL certificate for WinRM, which is needed to suport Powershell remoting in a workgroup environment.

Certificate creation starts with the Subject, SubjectAlternativeName, and the type of certificate (template)
[Distinguished Names](https://ldapwiki.com/wiki/Distinguished%20Names).

Also Needed are the Certificate's ValidityDurationDays and the KeySize

Example:

```Powershell
$Subject = @{
CN='WinRM'
Country='US'
StateOrTerritory='UT'
Organization='ATAPUtilities.org'
OrganizationUnit='Development'
SubjectReplacementPattern = 'CN="{0}",OU="{1}",O="{2}",ST="{4},C="{3}"'
} | Get-Subject  # return $SubjectReplacementPattern -f $CN, $OrganizationUnit, $Organization, $StateOrTerritory, $Country

$SubjectAlternativeName = @{
Email= 'SecurityAdminsList@ATAPUtilities.org'
SubjectAlternativeNameReplacementPattern = 'E="{0}"'
} | Get-SubjectAlternativeName # return $SubjectAlternativeNameReplacementPattern -f $EMail

$CertificateRequestConfigPath = Join-Path $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestConfigsPathConfigRootKey']]'SSLCertificateRequestTemplate.txt'

```

##### Create an Encryption Key PassPhrase File for the SSL Certificate Private and Public Key Pair

```Powershell
$EncryptionKeyPassPhrasePath = Get-CertificateSecurityDNFilePath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -BaseFileName 'SSLCertificatePassPhraseFile.txt' -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']]
New-EncryptionKeyPassPhraseFile -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath
```

##### Create an SSL Certificate Private and Public Key Pair

Example

```powershell
# Out filename template using Subject and SubjectAlternativeName
$EncryptedPrivateKeyPath = Get-CertificateSecurityDNFilePath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -BaseFileName 'SSLCertificateEncryptedPrivateKey.pem' -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityEncryptedKeysPathConfigRootKey']]
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
$CertificateRequestPath = Get-CertificateSecurityDNFilePath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -BaseFileName 'SSLCertificateRequest.csr' -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificateRequestsPathConfigRootKey']]
Create-CertificateRequest -Template $CertificateRequestConfigPath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -CertificateRequestPath $CertificateRequestPath
```

##### Generate the SSL Certificate and sign it with the Root Certificate Authority Certificate

Note that to do this, the function needs to know the CertificatePath, EncryptionKeyPassPhrasePath, the EncryptedPrivateKeyPath, the serial number file path, and the Certificate index filepath for the RootCertificateAuthorityCertificate that we want to sign it with

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
$CertificatePath = Get-CertificateSecurityDNFilePath -Subject $Subject -SubjectAlternativeName $SubjectAlternativeName -BaseFileName 'SSLCertificate.crt' -OutDirectory $global:settings[$global:configRootKeys['CertificateSecurityCertificatesPathConfigRootKey']]
$ValidityDays = 3650
Create-CertificateAndSign -EncryptedPrivateKeyPath $EncryptedPrivateKeyPath -EncryptionKeyPassPhrasePath $EncryptionKeyPassPhrasePath -CertificateRequestPath $CertificateRequestPath -validityDays $validityDays -CertificatePath $CertificatePath -CACertificatePath $CACertificateInfo.CertificatePath -CAEncryptedPrivateKeyPath $CACertificateInfo.EncryptedPrivateKeyPath -CAEncryptionKeyPassPhrasePath $CACertificateInfo.EncryptionKeyPassPhrasePath
# openssl x509 -req -in $CertificateRequestPath -CA $RootCertificateAuthorityCertificatePath -CAkey $RootCertificateAuthorityCertificatePath -CAcreateserial -out $WinRMSSLCertificatePath -days 3650

# openssl req -x509 -in $CertificateRequestPath -des3 -key $EncryptedPrivateKeyPath -passout file:$EncryptionKeyPassPhrasePath -sha256 -days $validityDays -out ```
# openssl req -x509 -new -nodes -key $SSLCertificatePrivateKeyPath -sha256 -days 1825 -out $SSLCertificatePath
# openssl req -x509 -new -key $SSLCertificatePrivateKeyPath -des3 -passout file:passphrase.txt -sha256 -days $validityDays -out
```

#### Save the SSL Certificate into a Vault

Use a specific vault for least privilege


Keep the following until testing proves them unnecessary (are the RootCA Cert and teh SSL cert private/public key pairs the same? what's the "best" way to generate the  PP Key pair)
##### Create a private/public key pair for the SSL certificate

``` Powershell
$WinRMSSLPrivateKeyPath = 'C:\Dropbox\SecretManagement\CARoot\PrivateKeys\WinRMSSLKey.private'
$WinRMSSLPrivateKeyPassphraseFilePath = join-path $global:settings[$global:ConfigRootkeys['SecureTemporaryDirectoryConfigrootKey']] 'WinRMSSLPrivateKeyPassphrase.txt'
# ToDo: make up a random passphrase and save it to a secret vault? Also plaintext backup for disaster recovery, only to USB. The write it to the temporary direcotry
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out $WinRMSSLPrivateKeyPath
# openssl genpkey -algorithm RSA -des3 -passout file:$WinRMSSLPrivateKeyPassphraseFilePath -pkeyopt rsa_keygen_bits:2048 -out $WinRMSSLPrivateKeyPath
```

Create a SSL certificate request (can be done on any machine)

``` Powershell
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

``` Powershell
$WinRMSSLCertificatePath = Join-path 'C:\Dropbox\SecretManagement\CARoot\Certificates' 'WinRMSSLCertificate.crt'
openssl x509 -req -in $WinRMSSLCertificateRequestPath -CA $RootCertificateAuthorityCertificatePath -CAkey $RootCertificateAuthorityCertificatePrivateKeyPath -CAcreateserial -out $WinRMSSLCertificatePath -days 3650

```

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

### Code Signing Certificates

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

### Secrets needed to deploy to any of the   'WebServerDropsBaseURLConfigRootKey' = 'FileSystemDropsBasePath'

## Secrets used by the CI/CD pipeline

## Secrets for 3rd Party Tools

### BeyondCompare License

### ServiceStack License


#### settings.json

### Visual Studio Code Extensions

#### Git

Store the remote repository URL and credentials

````
