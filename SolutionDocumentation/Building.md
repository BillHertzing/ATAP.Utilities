# Building the libraries, tools, and documentation (Repository / Solution level)

I am actively developing this documentation static website, and publishing to the ATAP Utilities GitHub Pages host. Over the course of the next few weeks, the site will be in a constant state of flux, but hopefully will settle down after the automation tools are completed and content is written.

Solution item Directory.Build.props has solution-wide settings for all build tasks
Solution item Directory.Build.targets has solution-wide targets and tasks for all build tasks
It includes the default targetframeworks,
*** because TargetFrameworks is being imported from Directory.Build.Props, and does not appear in the .csproj file, using the default project type GUID will result in Visual Studio thinking the project is old-style, and attempt an upgrade.
Ensuring that the project type GUID for .csproj files in the .sln is {9A19103F-16F7-4668-BE54-9A1E7A4F7556} will tell Visual studio that the .csproj is a new-style project. For example, Project("{9A19103F-16F7-4668-BE54-9A1E7A4F7556}") = "Library3", "Library3.csproj", "{ADFEAAF5-225C-4E13-8B65-77057AAC44B8}"\<EndProject> see also "Project Type GUIDs in the article https://github.com/dotnet/project-system/blob/master/docs/opening-with-new-project-system.md"
it includes the NuGet packaging and pusking properties and tasks
Versioning is very difficult problem, the ATAP.Utilities.BuildTools projects contains files that extend the build process and include tasks and functions that perform versioning andpackaging
## Visual Studio Extensions

CodeRush for Roslyn
GitHub Extensions
Powershell Tools for Visual Studio
VisualStudio.GitStashExtension
Microsoft Visual Studio Test Extensions
Project System Tools (Structured MSBUILD log viewer) https://marketplace.visualstudio.com/items?itemName=VisualStudioProductTeam.ProjectSystemTools and http://msbuildlog.com/

## NuGet packages

Both the c# code and the powershell modules need packaging. The two process are dissimilar, and need individual explanations

### powershell packaging

1) Create the .psm1 from the contents of the private and public subdirectories
2) Update the .psd1
3) Get the information from the .pssproj
4) Write the .nuspec
5) Pack the .nupkg


### Solution-wide
Install the MSBuild tasks and tooing to support rapid development builds, where each build should propagate to (local) NuGet feed.
Install-Package UtilPack.NuGet.Push.MSBuild
### Library Specific
#### Common to all Unit Test projects
Xunit
FluentAsserrtations
MOQ

Polly
Servicestack

## Historical lessons learned
Need is a way to version every Assembly/DDLL File/NugetPackage for lifecyclestages Development, QA, Staging, and Production
Versioning should be able to be applied at a solution level to all projects
Versioning should be applied to individual projects during development, and QA lifecycle stages.
Every visual studio build should increment the build number (or revision), and the NuGet packageversion
NuGet PackageVersion should mirror the major.minor.patch numbers found in the assembly version, with the addition of the string alpha/beta/RC-nnn
Solution-wide version numbers are stored in the .sln file, and represent the last public released version (major,minor.patch)
Project-specific version numbers are stored in a properties/AssemblyInfo.cs file.

Hardest part of the problem is hooking up the tasks that reads and changes the data inside of AssemblyInfo.cs fiile
task should run only if an assembly is going to be built (i.e., the .proj outputs are out-of-date with respect to the .proj inputs.
assemblyInfo.cs file should be changed only if the assembly is being built.
AssemblyVersion, AssemblyFileVersion, and AssemblyInformationalVersion are read from the assemblyInfo.cs file, and possibly modified and written back out to the same file.
If the solution or project is multitargeted, the assembly info is changed only once, and before the compilation portion of the build ocures.
If the solution or project is not multitargeted, the assembly info is still changed only once, and still before the compilation portion of the build ocures.
If the Major, Minor, Patch, Build, Version, and/or PackageVersion info in the Solution is greater than the corresponding version in the .proj file, then assemblyInfo.cs should be changed, and this should be done before the evaluation of inputs and outputs takes place

Set the parallel build options to build only 1 tasks to see the exact order that build tasks are called
Set the build verbosity to detailed  so the output has lots oof data about  the build process
tried adding properties and tasks in the Directory.Build.props file
tried the Visual Studio marketplace extensions Automatic Versioning from Precision Infinity
tried the Visual Studio marketplace extensions MsBump
tried extending the msbuild tasks by adding the MSCommunity Build Tasks files MSBuildTasks
tried adding properties and tasks in the Directory.Build.targets file
tried adding a new .targets file to the solution, ATAP.Utilities.BuildTooling.targets
tried adding inline task code written in C# to ATAP.Utilities.BuildTooling.targets
  Learend that inline code uses an old compiler, not Roslyn
tried adding the NuGet package RoslynCodeTaskFactory
  projects coulld not find the installed package location, the variable that is supposed to identify the path to the DLL was never set
tried building a DLL that holds the new tasks C# code, compiled and ready to run

ToDo:
Build the packages in Visual Studio and deploy to a local feed
Add tasks to sign assemblies
Deploy Beta checkin or better to a CI build tool (MyGet feed)
deploy RC or better to a public feed (NuGet)
Move other packages dependencies to package from project
Build Chocolatey package and install scripts
Add commands to the visual studio IDE using tasks.vs.json


Directory.Build.props are loaded before the microsoft targets
Directory.Build.targets are loaded after the microsoft targets
Directory.Build.props specifies the SolutionDir relative to the location where the build takes place
Directory.Build.props specifies the SolutionBuildToolsBaseDir where all the custom build tools are located, relative to the SolutionDir
Directory.Build.props specifies the MSBuildCommunityTasksPath where the MSBuild Community Extensions project's tasks extensions are located, relative to the SolutionBuildToolsBaseDir
Directory.Build.props specifies the ATAPUtilitiesBuildToolingTasksPath path, relative to the SolutionBuildToolsBaseDir
There are two different ATAP.Utilities.BuildTooling Assemblies, one for Net Full (used by Visual Studio IDE builds), and one for .NetCore (used by dotnet builds)
There are two diifferent configurations of the ATAP.Utilities.BuildTooling Assemblies, Release, which has no additional Debug logging, and Debug, which instructs the custom ATAP code to invoke additional debugging messages when it runs
Directory.Build.props specifies the correct ATAPUtilitiesBuildToolingTasksAssembly, based on the MSBuildRuntimeType, (VS IDE or DotNet), and the Release/Debug configuration.


Directory.Build.props specifies how version bumping happens
Directory.Build.props specifies where per-assembly version information is stored, in the VersionFile property
the VersionFile property in Directory.Build.props specifies the path to the AssemblyInfo.cs relative to the $(MSBuildProjectDirectory)

Directory.Build.props specifies NuGetLocalFeedPath which is the absolute location for a local BuGet package feed, but only if that property has not yet been defined.

Directory.Build.targets imports the MSBuild Community Extensions project's MSBuildTasks.Targets based on the MSBuildCommunityTasksPath
Directory.Build.targets imports the ATAP.Utilities.BuildTooling.Target based on the ATAPUtilitiesBuildToolingTasksPath

Directory.Build.targets defines a custom target "PublishAfterBuild", which runs after "Generate NuSpec" which uses Command="NuGet.exe push ..." to push the newly crteated NuGet package to NuGetLocalFeedPath

ATAP.Utilities.BuildTooling.Target contains the target PrintBuildVariables
PrintBuildVariables will log the values of many built-in and custom MSBuild properties, if the ATAPBuildToolingConfiguration property, as specified in the Directory.Build.props, is 'Debug'
PrintBuildVariables runs after the following targets: AfterTargets="_SetBuildInnerTarget; BeforeBuild; BeforeCoreBuild; GenerateNuspec">
ATAP.Utilities.BuildTooling.Target imports the tasks ""ATAP.Utilities.BuildTooling.GetVersion", "ATAP.Utilities.BuildTooling.NewVersionIfNeeded", "ATAP.Utilities.BuildTooling.SetVersion" from $(ATAPUtilitiesBuildToolingTasksAssembly)

ATAP.Utilities.BuildTooling.Target contains the target UpdateVersionifNecessary
UpdateVersionifNecessary runs before the target: BeforeTargets="DispatchToInnerBuilds"
UpdateVersionifNecessary calls the C# function GetVersion (found in $(ATAPUtilitiesBuildToolingTasksAssembly)) to parse the version information out of the $(VersionFile)
UpdateVersionifNecessary calls the C# function NewVersionIfNeeded (found in $(ATAPUtilitiesBuildToolingTasksAssembly)) to perform the logic that decides if the $(VersionFile) needs to be modified
UpdateVersionifNecessary calls the C# function SetVersion (found in $(ATAPUtilitiesBuildToolingTasksAssembly)) to modify the version information in the $(VersionFile), but only if NewVersionIfNeeded sets the property $(NewVersionNeeded) to true

$(ATAPUtilitiesBuildToolingTasksAssembly) contains C# functions used by the build tools.
Utilities.MakeBuild (static function) creates an integer used as the value of Build
Utilities.MakePackageVersion (static function) creates a string from the used as the value of NuGet Package Version
Utilities.TryParsePackageVersion (static function) returns a boolean, and creates a number of integers and strings that are the individual pieces of a parsed Nuget Package Version


The BuildTooling assembly gets locked by VS IDE when it does a build, the only way to replace/update it is to quit out of VS IDE. It is important to build both the debug and release versions together.

Visual Studio 2017 15. 8. 3 creates a NuSpec file during the packaging task. If a dependency on another package is found, the NuSpec file will specify a version of the required package of greater than 1.0.0. But before a package reaches version one while it is under development, the NuSpec file will not include a reference to restore the pre-V1 version of a file.

one way around this dilemma is to always create a version 1.0 as a package and there she was, even if there is only placeholders for functionality.. a better approach, is to put two minimal identifying piece of functionality into version 1.0.0. and includes unit test the test all four combinations of interrogation.

Every solution has a directory wide props and targets file. the targets file simply drains in the community msbuild extensions and VHF utilities buildtooling extensions

Custom tasks written in C sharp that help build Solutions and projects, are found in the project atsp.utilities. buikdtooljng. This is compiled into a dll, and package into a nougat package. Built in Drbug and release mode. is there or issue with Dell to installation, for when building something similar to Bill to him before the first version to ever exist.  CC top targets file has examples on turning on and turning off conditionally calls to the custom task.

ATAP.Utilities.BuildTooling.CSharp
C's files contains the code for tasks It demonstrates 3 custom tasks. One task gets the version file information to get the current information. Another tasks knows how to update the version file. A third task, UpdateVersion
, Knows how to get version information from the current .csproj file, calls Get version for version information, compares the  two,  decides what the new version information should be, and sets that information into the version file.

The version information is inspected once for each project involved on every build. .

#Visual Studio Tips and Techniques
This section provides informatio on how to use the features of Visual Studio 2017, and theinstalled extensions, to improve your code quality and reduce your coding frustrations

## MSBuild Logging and Build Log Viewer

Visual Studio 2017 (version 15.4 or later)
Install the Project System Tools extension (insert xref to instructions)
In Visual Studio, choose the View > Other Windows > Build Logging menu item.
Click on the "play" button.
This will cause design time builds to show up in the build logging tool window. If you have the MSBuild Binary and Structured Log Viewer installed, you can double-click on a log to view it in the viewer, otherwise you can right-click and choose Save As... to save the log in the new binary log format.
### Installing the structure log vieweer
https://github.com/KirillOsenkov/MSBuildStructuredLog/releases/download/v2.0.46/MSBuildStructuredLogSetup.exe


## Deterministic builds

[Deterministic Builds](https://github.com/clairernovotny/DeterministicBuilds) - needed for traceability, also related to Source Link and Symbol Packages. Or another option is to pass it to msbuild or dotnet with /p:ContinuousIntegrationBuild=true (not for Debug configuration, just Release and ReleaseWithTrace)

## app.config in project files

Only goes into .csproj files for executables, not libraries.
For Plugins (which are loaded at runtime), you may need an app.config for the Main.exe. put  specific .app

[app.config file in the new .csproj format](https://stackoverflow.com/questions/59959513/app-config-file-in-the-new-csproj-format) - Martin Ullrich - good instructions and explanation. the PrepareForBuild msbuild target will automatically pick up the file and subsequent build steps can also edit this file as the logical file.

<AppConfig>App.config</AppConfig>


[How to not copy app.config file to output directory](https://www.py4u.net/discuss/730689)
1.Choose the value $(AppConfig) set in the main project.
1.Choose @(None) App.Config in the same folder as the project.
1.Choose @(Content) App.Config in the same folder as the project



## Signing the Code (Authticode Signing Service)

Nice article here [Authenticode Signing Service and Client](https://github.com/dotnet/SignService) a Azure-based service that allows a CI/CD pipeline to sign artifacts using a key held in an Azure HSM vault.

[RSAKeyVaultProvider](https://github.com/novotnyllc/RSAKeyVaultProvider) info on RSA key vaults in Azure


# Image Optimization

[imgbot](imgbot.net) - lossless compression, but only in GitHub. Automatically sends a pull request to the repository.


## Powershell Packaging

[Hitchhikers Guide to the PowerShell Module Pipeline](https://xainey.github.io/2017/powershell-module-pipeline/)

[PowerShell Scaffolding – How I build modules](https://invoke-automation.blog/2019/09/24/powershell-scaffolding-how-i-build-modules/)

[PlasterTemplates](https://github.com/KevinMarquette/PlasterTemplates)

[Catesta](https://github.com/techthoughts2/Catesta)

[PlasterPlethora | A plethora of Plaster templates.](https://kandi.openweaver.com/powershell/larssb/PlasterPlethora#Summary)

[Jenkins - User Interface for your Powershell tasks by Kirill Kravtsov](https://www.youtube.com/watch?v=2lrrrknwy5M)

`Register-PackageSource -Name chocolatey -Location http://chocolatey.org/api/v2 -Provider PSModule -Verbose`

`Register-PSRepository -Name 'LocalRepo' -SourceLocation 'C:\Repo' -PublishLocation 'C:\Repo' -InstallationPolicy Trusted`
 
 `Register-PSRepository -Name 'LocalDevelopmentPSRepository' -SourceLocation '\\utat022\FS\DevelopmentPackages\PSFileRepository' -PublishLocation '\\utat022\FS\DevelopmentPackages\PSFileRepository' -InstallationPolicy Trusted`

 Publish-Module -Path .\MyModule -Repository Demo_Nuget_Feed -NuGetApiKey 'use real NuGetApiKey for real nuget server here'

[NuGet package manager – Build a PowerShell package repository](https://4sysops.com/archives/nuget-package-manager-build-a-powershell-package-repository/)

[Build and install local Chocolatey packages with PowerShell](https://4sysops.com/archives/build-and-install-local-chocolatey-packages-with-powershell/)

[Understanding Chocolatey NuGet packages](https://4sysops.com/archives/understanding-chocolatey-nuget-packages/)

(https://github.com/psake/PowerShellBuild)

[Build Automation in PowerShell](https://github.com/nightroman/Invoke-Build)

[Catesta is a PowerShell module project generator](https://github.com/techthoughts2/Catesta)





