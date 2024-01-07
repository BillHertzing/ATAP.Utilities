 
# ATAP.Utilities Conceptual Documentation ReadMe
If you are viewing this ReadMe.md in GitHub, [here is this same ReadMe on the documentation site]()
## Introduction
Detailed Documentation for the following topics as they pertain to this repository

There have been many people and organizations whose published insights helped shape this effort. A partial list of these fine folks can be found in the [Attribution document](./Documentation/ATTRIBUTION.html) .
## <a id="GettingStarted" />Getting Started

This repository is intended to be a demonstration of the many many tools and processes needed to produce a real-world complex application. It tackles a great majority of the processes needed to produce a configurable platform-targeted multi-lingual production-ready application for .Net in C# and Powershell, including development, analysis, testing, packaging, and deployment. It include automated documentation generation, including diagrams, and static site generation of the documentation. It tackles databse development, testing, packaging and deployment, along with version control and datbase backup.

The non-documentation Projects in this repository are written in C#, Powershell, and SQL. Documentation is written in Markdown, Unified Modelling Language (UML), and DrawIO. 



### <a id="Prerequisites" />Prerequisites

There are a lot of prerequisite packages needed to handle all the features of the repository. 
* Windows 10 or 11
* WSL for Windows
* .Net for Desktop
* .Net Core
* Powershell V7
* Git
* Visual Studio Code IDE
    * Plugins


### Suggested Additional tools and utilities

## Overview

ToDo: Insert diagram of development process

ToDo: Insert diagram of CI/CD process

## <a id="Development vs. CI/CD" /> Development vs. CI/CD

There is a distinction that needs to be made between the tasks related to developing a project or feature, and the CI/CD pipeline that produces the production-ready package and artifacts about that package (i.e., test results, test coverage, published security and dependency anlaysis, documentation, installers, etc.).  

All of the tools used in development or production-ready processing, will be referred to as the "Process Ecosystem". To produce a production-ready new package, feature, or bugfix, all process involed should be themselves use only production versions of the tools. See [3rd party tool evolution](#3rd-party-tool-evolution) for a discussion on how to test and integrate a new version of a process tool.  Furthermore, to achieve repeatable results, all of the tools used for a particular production-ready package should be identified and recorded along with the tool's version information

During the process of development, almost all of the tools used in the CI/CD process are run by the developer, to ensure the code in the PR doesn't fail in the CI/CD pipeline. The developer also needs to ensure that the CI/CD pipeline works end-to-end for the code under development. During this period, the tools are being invoked under the context of the developer's account.

During the CI/CD pipeline, the code in the PR goes through the entire CI/CD process, and the pipeline decides if the code passes sufficient testis to go into production. If so, the code is packaged and pushed to deployment. During this process, the tools are being invoked under the context of a `ServiceAccount`

### 3rd party tool evolution

All of the tools used in producing a production-ready package are themselves software, and as such can be subject to development and updates. Often overlooked, the process of installingh, testing, and validating a new version of a tool into the process ecosystem

## <a id="Building" /> Building

The non-documentation Projects in this repository are written in C#, Powershell, and SQL. Documentation is written in Markdown, Unified Modelling Language (UML), and DrawIO. 

## <a id="Publishing" />Publishing

## <a id="Debugging" />Debugging

## <a id="Packaging" />Packaging

### <a id="NuGetPackaging" />NuGet

### <a id="ChocolateyPackaging" />Chocolatey

## <a id="Installing" />Installing

## <a id="Using" />Using
### <a id="ConsumingUtilityPackages" />Consuming Utility packages

### <a id="UsingBuildTooling" />Using BuildTooling

### <a id="UsingPowerShellScripts" />Using PowerShell Scripts

## Validating the processes

Having good process defined and implemented iis important. Also important is validating that there are no errors in the tools data.

### Confirm-GitFSCK


## Disiater Prepardness

In the event of a disaster that renders the computers used in the creation of software themselves useless, it is critical that a record is made (and safely stored) of the contents of the settings and configurations of all the tools
## Backup and Restoration of tool's data

Many of the tools used in the development and CI/CD process have settings and configurations. 

### Visual Studio Code

#### settings.json

### Visual Studio Code Extensions

#### Git

Store the remote repository URL and credentials

#### SpellCheck

store the list of exceptions, for each repository workspace and for each user
