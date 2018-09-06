# Instructions for building the libraries

Solution item Directory.Build.props has solution-wide settings for all build tasks
Solution item Directory.Build.tarhets has solution-wide targets and tasks for all build tasks
It includes the default targetframeworks,
it includes the NuGet packaging and pusking properties and tasks
Versioning is very difficult problem, the ATAP.Utilities.BuildTools projects contains files that extend the build process and include tasks and functions that perform versioning andpackaging
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


The BuildTooling Assembly gets locked by VS IDE when it does a build, the only way to replace/update it is to quit out of VS IDE.
