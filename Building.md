# Instructions for building the libraries

Solution item Direcotry.Build.props has solution-wide settings for all build tasks
It includes the default targetframeworks,
it includes the NuGet packaging and pusking properties and tasks

## Visual Studio Extensions
Precision Infinity's Automatc Versions 1
CodeRush for Roslyn
GitHub Extensions
Powershell Tools for Visual Studio
VisualStudio.GitStashExtension
Microsoft Visual Studio Test Extensions

## NuGet packages
### Solution-wide
Install the MSBuild tasksa and tooing to support rapid development builds, where each build should propagate to (local) NuGet feed.
Install-Package UtilPack.NuGet.Push.MSBuild
### Library Specific
#### Common to all Unit Test projects
Xunit
FluentAsserrtations
MOQ

Polly
Servicestack
