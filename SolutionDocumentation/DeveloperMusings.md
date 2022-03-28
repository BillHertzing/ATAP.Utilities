# Developer Musing

## Overview

This document is a place to document why certain design decisions were taken.

## Security and Secrets, high level and complex goals

An organization building OSS apps and libraries, and publishing these, has a need to protect secrets like passwords,API keys, and other information needed to access resources, both internal and internet-provided.

### Users

Users includes both real people and 'Service accounts'. Service Accounts provide the context under which specific services run. Think of SQL Server service, Jenkins Service, etc.  All of these users will need access to secrets

### Roles

The best security practices only give users the minimum access they need to do their job functions. Indeed, user's should not even know that other secrets exist.  To accomplish this, there is a defined set of security roles in the organization, and users are assigned to none, 1, or more of these security-roles

### Security Subsystem

An organization should have a dedicated Security Subsystem (SecSub). The SecSub should have interfaces (functions or APIs) that allow users to get/set secret vaults according to their roles. The SecSub should have other interfaces that allow security admins to create. delete, and modify security vaults.

### User Process Startup

When a user's profile executes, it requests it's set of Secrets Vaults from the SecSub. Then user programs can get/set secrets from these vaults.

### Machine-level security

#### Powershell

There are two modules that are used by Powershell to access Secrets in SecretManagement vault extensions. Loading these modules from the internet into a user's scope takes quite a bit of time (four seconds per module on my main machine). Starting a user process happens all the time, so we want to minimize how long it takes to spin up a process. For this reason, loading these two modules into a machine scope, and doing it just once per machine, would be more efficient.

The SecSub has multiple functions that should only be accessible to a security-admin role.

One SecSub function is to Load/Remove/Update the `Microsoft.PowerShell.SecretManagement` and `Microsoft.PowerShell.SecretStore` modules at a machine scope.

So loading them once into a machine scope will eliminate this delay. The `src\ATAP.Utilities.Powershell\Profiles\AllUsersAllHostsV7CoreProfile.ps1` profile will

## ## Security and Secrets, More Musing on Security at the implementation level

The current third iteration of a design for reasonable security without onerous intrusiveness.

One of the concerns for individuals trying to start an OSS project is lack of financial resources, hence one of the requirements of the SecSub is that it work on a collection of computers that do not participate in any LDAP protocol, that is, are not part of a Microsoft domain or a Linux LDAP network.

The Internet suggests solutions that utilize the Powershell SecretManagement modules. It also suggests securing the password to the SecretVault by encrypting it, and subsequently decrypting it, using a Data Encryption Certificate (X500) installed to specific machines, per-user. This seems feasible for small to medium to large networks, as the installation using CertReq.exe can be done remotely via a CIMSession, using both ComputerName and RunAs parameters. It prevents access to secrets on any machine which does NOT have the encryption certificate loaded, and it blocks access to secrets by other users on machines where some users have access to secrets. This includes CI/CD machines, which run many processes on the Build and Test machines under the context of the many Service Accounts (JenkinsAgentSrvAct, JenkinsControllerSrvAc, MSSQLSrvAcct, MySQLSrvAcct, etc.), and the Production machines, which run the production instances of those Service Accounts for the organization's Product.

The attempt to implement the First Design Brainstorming ran into problems with Powershell SecretManagement because the design used individual and group SecretVaults, ie.e, multiple Secretvaults. But the [PS SecretManagement only supports a single SecretVault](https://github.com/PowerShell/SecretStore/issues/58), not multiple.

The attempt to implement the Second Design Brainstorming ran into problems with Powershell SecretManagement because the design used a shared cloud location as the location of a SecretVault. But the [PS SecretManagement places the SecretVault on a local disk and locks it down with ACLs (Windows) or file permissions (Linux)](https://github.com/PowerShell/SecretStore/blob/master/Docs/ARCHITECTURE.md#file-permissions). Another problem with the Second Design Brainstorming was the complexity of the SecSub it proposed.

Third Design Brainstorming
The "SecurityAsAMicroService" AKA the SecuritySubsystem (SecSub) is a great idea, but will need the full ATAP.Service.GenerateCode service to be written and useful, to create a subsystem of the desired complexity.

The core functions are being written into the Powershell Machine Profile, and will be eventually abstracted into an ATAP.Utilities.Security.Powershell module.

The initial core functions that will be used by ordinary users will be for getting and setting secrets and secret metadata, for specifying and unlocking one SecretVault. There is a core function that handles unlocking the Vault, and it can be called anytime, for example get-secret fails (hopefuly it will indicate a password issue). This is used when long-running processes request a secret after a prior unlocking times-out.

There are some other core functions written for administration, that will be run once when setting up the Data Encryption Certificate for each user, and the encrypted password, which, when decrypted as a SecureString, will used as the master password for the SecretVault for each user. The same Data Encryption Certificate will be used on on each machine that the user has a login. The encrypted password will be stored in a Json structure in the EMBs file. While the structure is a a hastable, it is ordered, and only the first entry is used. Hopefully, there will eventually be a technology that supports multiple SecureVaults per user. The core functions are written to allow for simple expansion. Additional properties for each Master Password entry can be defined for use with the lifecycle of the EMB. "DateCreated" and "Expiration" are defined. Expiration matches the expiration of the Data Encryption Certificate

There are some other core functions written for administration, that will be run once when setting up the SecretVault for each user on each machine. The VaultConfiguration function, for a password, uses the SecureString decrypted using the Subject property from the first entry of the EMBs file. For a password timeout, it uses the timeout property.

There are some other core functions written for a scheduled task, which can be run under any scheduler that can run Powershell, that runs on every machine/user pair, and copies the SecureVault subdirectory, the list of the secrets stored in the vault (just names and metadata, not values, will be used in disaster recovery to identify the information needed if the Securevaults have to be recreated from scratch), the Encrypted Master Passwords, the Data Encryption Certificates, the Data Encryption Certificate Requests, and the user's securevaultregistration into a .zip file, passwordprotects it, and copies it to a secure backup location (Dropbox Vault?) Also (Very Important!) it alerts someone that the password and certificate are due to expire (ToDo: add that alert to the organizations dashboard!)

Finally, there is a core function to

Second Design Brainstorming

Every organization should have a group whose primary focus is security. In today's world security tasks should be automated as much as possible. Automated security tools used by an organization should be organized under a Security subsystem.

As a security administrator, the security processes should perform the following:

Set and retrieve secrets. Updating a secret should make the new information available to all roles that need it on all machines where teh role is expected to operate
Create, Delete and Update Security roles, which identify groups of secrets needed to perform an organizational role
Assign, and revoke, users's association with Security roles
Restrict a user's access to secrets to just those secrets needed to perform an organizational role
Transparently provide a user access to their secrets
ToDo: Log all access attempts to the SecSub
ToDo: Log all changes to secrets and roles and associations, including date/time and the authorized security administrator (user) making the change
ToDo: include more best practices for managing security within an organization

Creating a SecSub, and defining the processes to use it, is an ongoing effort. This document, and the processes it covers, are currently being developed

Developers, Database Administrators, and the autonomous CI/CD processes need access to secrets.

Powertshell is the script interpreter used by many of the users

Powershell SecretManagement

Powershell provides two modules for Secrets, the  SecretManagement and the SecretStore

The SecretStore can interface with 3rd-party password storage soultions, or it can use a Powershell default SecretStore. The ATAP.Utilities will use the least expensive option, the Default SecretStore

A Powershell SecretStore is created per machine and per user, and cannot be shared

All of the secrets need

First Implementation Idea:
Secrets are encrypted and stored in a Password Vault.
The password Vault file is stored in a secure cloud location, accessable from any user on a group machine (I use a Dropbox account, in the Dropbox Vault location)
Powershell Secrets Module is used to register a password Vault, on a per-user, per-machine basis. Vault registration information is stored under %LOCALAPPDATA%\Microsoft\PowerShell\secretmanagement in Windows and `$HOME/.secretmanagement` for non-Windows ToDo: lookup). Vault registration can be done in the Powershell machine profile, so it is done automatically and available to any script run by any user
Unlocking a vault, so Secrets can be retrieved, requires the master password for the vault.
powershell scripts that are run by non-interactive users cannot enter a password at a prompt.
Powershell scripts can unlock a vault if they have the master password for the vault.
To be stored in a file,a master password should first be encrypted.
Windows has a data protection encryption API and Powershell has a module to access those APIs
Data encryption on a Windows computer can be done by installing a Data Encryption Certificate into the certificate data store on a per-user per machine basis.

The order of the steps to follow are:
Identify the names of the SecretManagement extension vaults to be created (most organizations need only one, but larger organizations may want individual vaults for various roles)

In the global configuration, identify the location of the `SCVP` (Secure Cloud Vault Path) on a per-machine basis
In the global configuration, identify the location of the `EMBs` (Encrypted Master Passwords) subdirectory, under the `SCVP`,  on a per-machine basis
In the global configuration, identify the location of the `SMVs` (Secret Management Vaults) subdirectory, under the `SCVP`,  on a per-machine basis
In the global configuration, identify the location of the `DECs` (Data Encryption Certificates) subdirectory, under the `SCVP`,  on a per-machine basis

In the global configuration, identify the name and location of each `DataEncryptionCertificate.inf` files, one for each SecretManagement extension vault.

DoOnce: Create the `SCVP` directory and the three subdirectories under it
DoOnce Create a custom type `SMEVInfo` (SecretManagement Extension Vault Information) having four fields, `Name`, `Path `, `EncryptedMasterPassword`, `DataEncryptionCertificateSubject`

DoOnce:
For each SecretManagement extension vault
From a `DataEncryptionCertificate.template` file, create a  `SMEV.Name.inf` file for a data encryption certificate for each vault. The "Subject" line must be different for each SecretManagement extension vault. Save these into the `DECs` (Data Encryption Certificates) subdirectory
generate a random GUID
Create each SecretManagement extension vault using the random GUID as a password, and if using a standard Powershell vault, place them under the `SMVs` subdirectory

use Powershell encryption cmdlets (Protect-CmsMessage) to encrypt the GUID into a SecureString using the data encryption certificate created in the earlier step

instantiate a `SMEVInfo`, loading the fields with the vault name, path, encrypted master password, and the `Subject` line of the `.inf` file
accumulate each `SMEVInfo` into a `SMEVInfos` collection

write the `SMEVInfos` collection as json , including the encrypted SecureString -AsPlainText, to a file in `EMB` called `AUMPs.txt` (ATAP Utilities Master Passwords)

Do Once per machine
create a CIM session on each machine in the group running as an administrator
Install the Encryption module for that machine
Install the SecretManagement module and SecretsVault modules for that machine

Do Once per (machine, user) cross-product

Create a CIM session on each machine in the group running as the user
open the `AUMPs.txt`, read the json, then for each `SMEVInfo` object
run the certreq.exe program and use it to install each Data Encryption Certificate to that user's personal certificate store
Register the SecretManagement extension vault by name and path

Using: (in machine profile so all pwsh scripts have access to the secrets)

1) validates the presence of the encryption and secrets modules, importing them if necessary
1) Validates the presence of the machine-specific `EMB` directory.
1) Validates the presence of the machine-specific `AUMPs.txt` file.
1) open the `AUMPs.txt`, read the json, then for each `SMEVInfo` object
1) Get the SecretManagement extension vault by name
1) send the `SMEVInfo` `EncryptedMasterPassword` to the the decrypt function using the `DataEncryptionCertificateSubject` , and use the results to unlock each SecretManagement extension vault
any errors means the user is not authorized, just ignore any errors in the machine profile
1) test each SecretManagement extension vault

