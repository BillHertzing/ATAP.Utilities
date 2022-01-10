
# ATAP.Utilities Conceptual Documentation
If you are viewing this ReadMe.md in GitHub, [here is this same ReadMe on the documentation site]()
## Introduction
Detailed Documentation for the following topics as they pertain to this repository

There have been many people and organizations whose published insights helped shape this effort. A partial list of these fine folks can be found in the [Attribution document](./SolutionDocumentation/ATTRIBUTION.html).

## <a id="VIsion" />Vision

## <a id="GettingStarted" />Getting Started

Getting Started is a bit of an undertaking, as there are a lot of third party tools used. Here are the details of setting up the environment to build and use these utilities. [GettingStarted](./SolutionDocumentation/GettingStarted.html)

### <a id="Prerequisites" />Prerequisites

If you just want a list of the third party tools needed so you can 'checklist' them, here they are in a nutshell. [Prerequisites](./SolutionDocumentation/Prerequisites.html)

### Suggested Additional tools and utilities

These are the 3rd party tools needed to experiment with the cutting edge and experimental features

## <a id="Building" /> Building

As the [Vision]() notes, the biggest utility in the library is the CodeGeneration feature. Building and versioning an engine that builds versioned code and BOM's has some interesting edge cases. You can find out how to build the utility in the [Building](./SolutionDocumentation/Building.html). The focus of this document is how tosetup all the development environment tools needed to create modified code and how to analyze it, test it and how to create and test deployment scenarios. Includes details on setting up an IDE, analysis tools, build tools, testing tools, static site servers for testing, dynamic site servers for testing

## <a id="Debugging" />Debugging

[Debugging](./SolutionDocumentation/Debugging.html)

## <a id="Testing" />Testing

The Testing documentation includes how to use the suported unit test frameworks and thirsd party tools, coverage tools, static analysis toolss should be writeen, coverage toolsThis includes The CI portion of the versioned CI/CD pipeline configuration and tasks, which is constantly evolving, is part of this documentation. [Testing](./SolutionDocumentation/Testing.html)

## <a id="Packaging and Publishing" />Publishing

The CD portion of the versioned CI/CD pipeline configuration and tasks, which is constantly evolving, is part of this documentation group.

## <a id="Publishing" />Publishing

Some of the installation built and managed are 'real-time installations, that update their outputs regularly. After the engine is rebuilt, or changes are made to an installation's requirements/inputs/content, the installation's outputs have to be updated. Some installations, like static sites mostly hosting blogposts, publish their approved source changes to cloud/hosting companies. When utility installations are updated, the package outputs of the versioned installation are updated, tested, and pushed out to that package's public distribution sites, as defined in the utility's current installation.

web applications

[Publishing](./SolutionDocumentation/PackagingAndPublishing/Publishing.html)

## <a id="Packaging" />Packaging

Installations that create code packages and utility code, including libraries, CLI utilities, console programs and services output packages that are copied out to public internet accessable locations from which clients access and utilize them.

### <a id="NuGetPackaging" />NuGet

[NuGetPackaging](./SolutionDocumentation/PackagingAndPublishing/NuGetPackaging.html)

### <a id="ChocolateyPackaging" />Chocolatey

[ChocolateyPackaging](./SolutionDocumentation/PackagingAndPublishing/ChocolateyPackaging.html)

### <a id="NPMPackaging" />Chocolatey

[NPMPackaging](./SolutionDocumentation/PackagingAndPublishing/NPMPackaging.html)

## <a id="Installing" />Installing

## <a id="Using" />Using
### <a id="ConsumingUtilityPackages" />Consuming Utility packages

### <a id="UsingBuildTooling" />Using BuildTooling

[UsingBuildTooling](./SolutionDocumentation/Using/UsingBuildTooling.html)

### <a id="UsingPowerShellScripts" />Using PowerShell Scripts

[UsingPowerShellScripts](./SolutionDocumentation/Using/UsingPowerShellScripts.html)

### <a id="UsingConsoleCLIUtilities" />Using Console CLI Utilities

[UsingConsoleCLIUtilities](./SolutionDocumentation/Using/UsingConsoleCLIUtilities.html)

### <a id="UsingServices" />Using Services

[UsingServices](./SolutionDocumentation/Using/UsingServices.html)

### <a id="UsingAPIInterfaces" />Using API interfaces to Services

[UsingAPIInterfaces](./SolutionDocumentation/Using/UsingAPIInterfaces.html)
