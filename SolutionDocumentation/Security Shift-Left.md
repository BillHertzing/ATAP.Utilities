
# Security in the Libraries, Packages and CI/CD pipeline

If you are viewing this `Security Shift-Left.md` in GitHub, [here is this same Disaster Preparedness on the documentation site]()

## <a id="Introduction" />Introduction

Security is everyone's business in software development. The applications and libraries being developed as 'product' should have security as a first-class citizen. Automated scanning tools should, during the build, inspect and analyze the code being developed for known security flaws and best practices. The 3rd-party SW being used in the product (the items in the Software Bill of Materials (BOM)) should report their compliance with security best practices, and these 3rd party softwares and their security score made available in the build artifacts included in the packages.

The CI/CD pipeline will need access to "secrets" that authorize access to certain sensitive information. For example, credentials to access Git, credentials to access cloud storage location, Code Signing certificates, SHA generation, database credentials, passwords for service accounts all need to be secured and protected from disclosure.

The locations to which products are deployed are usually protected by credentials to ensure only authorized production packages are deployed

The developer's machines all need individual security to handle user and Service passwords, authorization tokens from cloud services,

## <a id="GettingStarted" />Getting Started



## <a id="Prerequisites" />Prerequisites

#### Security Analysis Tools Prerequisites

* the Github service that scans repositories and PRs

* Dependabot for listing dependency packages

* License analysis

#### Code Signing Certificates Prerequisites

#### Database Credentials Prerequisites

#### Cloud Storage Credentials Prerequisites

##### Dropbox Access Credentials Prerequisites

##### GoogleDrive Access Credentials Prerequisites

##### OneDrive Access Credentials Prerequisites

#### On-Premise Hot Backup locations Prerequisites

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

