# ATAP.Utilities.BuildTooling.CSharp

If you are viewing this ReadMe.md in GitHub, [here is this same ReadMe on the documentation site]()

## Introduction

This project provides:
an additional Targets file that can be imported in a project's build definition (.csproj)
a .dll file that contains additional MSBuild Task definitions written in CSharp

Authenticated ProGet publishing is delegated to
`Invoke-ProGetNuGetPublish.ps1`. MSBuild supplies only
`ProGetApiKeySecretName` (administrator by default because the legacy replace
workflow deletes before pushing); the wrapper resolves the value through
`Get-SecretATAP` only at the authenticated leaf.

Repository-wide C# build health checks run through
`Build\Invoke-RepoHealthGate.ps1` after restore and before pack or publish.
Those checks live outside this project and outside PowerShell module package
tests because they audit shared `Directory.Build.props` behavior across the
repository.

Repository-wide C# build health checks run through
`Build\Invoke-RepoHealthGate.ps1` after restore and before pack or publish.
Those checks live outside this project and outside PowerShell module package
tests because they audit shared `Directory.Build.props` behavior across the
repository.

## ATAP.Utilities.BuildTooling.Targets

This is a .targets file that can be imported into a project, either by inclusion in a .csproj file, or solution-wide by inclusion in to a Directory.Build.props file

### BeforeCompile Tasks

---Stoping point---

Additional tasks and targets for MSBuild extensions

- additional Targets file
- Additional BeforeCompile Tasks to evaluate a project's inputs and outputs
- Tasks to Create a lockfile, and update the AssemblyInformation in Properties/AssemblyInfo.cs
- Tasks to Delete the Lockfile \* conditional call UpdateAssemblyVersion if the lockfile does not exists

* DLL with these tasks (**OBSOLETE** — wrapped in `#if false`, not compiled):
  > These three MSBuild Task classes have been superseded by
  > [Nerdbank.GitVersioning (NBGV)](https://github.com/dotnet/Nerdbank.GitVersioning).
  > The code is retained for historical reference only.
  - ~~GetVersion~~ — read AssemblyVersion, AssemblyFileVersion, and AssemblyInformationalVersion from an `AssemblyInfo.cs` file.
  - ~~SetVersion~~ — write updated version values back to an `AssemblyInfo.cs` file.
  - ~~UpdateVersion~~ — combine GetVersion + MakeBuild + MakePackageVersion + SetVersion into a single build step.
