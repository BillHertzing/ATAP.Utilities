# ATAP.Utilities.BuildTooling.CSharp
If you are viewing this ReadMe.md in GitHub, [here is this same ReadMe on the documentation site]()
## Introduction
This project provides:
    an additional Targets file that can be imported in a project's build definition (.csproj)
    a .dll file that contains additional MSBuild Task definitions written in CSharp

## ATAP.Utilities.BuildTooling.Targets
This is a .targets file that can be imported into a project, either by inclusion in a .csproj file, or solution-wide by inclusion in to a Directory.Build.props file

### BeforeCompile Tasks

---Stoping point---

Additional tasks and targets for MSBuild extensions
    * additional Targets file
        * Additional BeforeCompile Tasks to evaluate a project's inputs and outputs
        * Tasks to Create a locakfile, and update the AssemblyInformationin Properties/AssemblyInfo.cs
        * Tasks to Delete the Lockfile
        * conditioanl call UpdateAssemblyVersion if the lockfile does not exists

    * DLLL with these tasks:
        * GetVersion
        * SetVersion
        * UpdateVersion
