<!-- <base href="http://localhost:8080/">-->
 <base href="https://BillHertzing.GitHub.io/"> 
# ATAP.Utilities.BuildTooling.CSharp
This project provides:
    an additional Targets file that can be imported in a project's build definition (.csproj)
    a .dll file that contains additional MSBuild Task definitions written in CSharp

# ATAP.Utilities.BuildTooling.Targets
This is a .targets file that can be imported into a project, either by inclusion in a .csproj file, or solution-wide by inclusion in to a Directory.Build.props file
## Additional properties

## Additional Tasks

# ATAP.Utilities.BuildTooling.CSharp DLL\
This is a DLL that contains additional custom MSBuild tasks
* GetVersion
* Set Version
* UpdateVersion

## Get Version

## Set Version

## Update Version
1. Before calling CoreCompile for the first TargetFramework, determine if the project will be built, or if it is up-to-date. If up-t-date, do nothing with version information
1. if the project is not up-to-date, do the following before building the first TargetFramework
    1. if Debug is true, Call GetVersion to get the current version information from the VersionInfoFile, and log the current version information in the build output.
    1. create a lockfile, using the MSBuild Community Tasks custom build task's Touch task.
	1. if the lifecycle stage is development, calculate the new NuGet package version string
	1. calculate the new Build and Revision integers
	1. execute the SetVersion tasks to update the version information in the VersionInfoFile
3. after the compile for all targets is completed, remove the lockfile.

### BeforeCompile Tasks

