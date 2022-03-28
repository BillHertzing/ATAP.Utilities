
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



#### Security Analysis Tools Prerequisites

* the Github service that scans repositories and PRs

* Dependabot for listing dependency packages

* License analysis

#### Data Encryption Certificates Prerequisites
For Installation on Windows, the CertReq.exe program must be available
ToDo: write details For Installation on Linux
#### Code Signing Certificates Prerequisites

#### Database Credentials Prerequisites

#### Cloud Storage Credentials Prerequisites
For Windows:
    Dropbox:
    Cropbox Valut:
    OneDrive:
    GoogleDrive:

##### Dropbox Access Credentials Prerequisites

##### GoogleDrive Access Credentials Prerequisites

##### OneDrive Access Credentials Prerequisites

#### On-Premise Hot Backup locations Prerequisites
For Windows:

#### Off-Premise Cold Backup locations Prerequisites

## Overview

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

### GoogleDrive  Access Credentials

### Local Network File Shares Credentials

### Local Web Server Read and Write Credentials

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

### ServiceStack License

#### settings.json

### Visual Studio Code Extensions

#### Git

Store the remote repository URL and credentials

