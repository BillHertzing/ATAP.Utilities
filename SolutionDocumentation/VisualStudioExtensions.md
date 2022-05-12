<h1> Visual Studio settings and Extensions needed to build ATAP.Utilities solution and project</h1>
#
# Visual Studio settings and Extensions needed to build the libraries, tools, and documentation (Repository / Solution level)

# VSIX extensions
## GhostDoc Community Edition (tbd)
    *  Used to create XML documentation inside each .cs file that socuments public classes, fields, methods, and properties.
    *  Machine-wide configuration settings for GhostDoc are stored here: TBD
    *  Solution-wide configuration settings for GhostDoc are stored here: TBD
    *  Project-wide configuration settings for GhostDoc are stored here: TBD
### Installation Details
    * use standard installation instructions

## DocFx (tbd)
    * used to create a static web site from the XML documentation in the .cs files
    * Templates for the static web site are stored here:
    * additional content (CSS and JS) are stored here:
    * Configuration information to publish the static website to GitHub pages is stored here:
### Installation Details
    * use standard installation instructions
	choco install docfx -y for a machine-wide installation

### The AutoDoc project in a Solution
    * This project builds the static documentation website.
    * The gh-pages branch of a repository should point to the latest release version of this project.
    * The repository's ReadMe.md file should contain a prominent link to the Doc directroy of this project
    * see also https://dzone.com/articles/generating-documentation-with-docfx-as-part-of-a-v

To speed up development, do NOT build the AutoDoc project automatically.
    * On the VS menu bar, choose Build > Configuration Manager.
    * In the Project contexts table, locate the project you want to exclude from the build.
    * In the Build column for the project, clear the check box.

Build the AutoDoc project using the command line and the --serve option to preview your changes.
# Visual Studio Configuration settings
    * tbd

# msBuild custom targets and tasks from ATAP
## Targets
    * Target that executes if a projects output are invalid with respect to the project's inputs
    * Target that creates a lockfile
    * Target that deletes a lockfile
    * Target that  calls the Task to create a lockfile if project outputs are invalid with respoect to inputs
:TBD

## Tasks
    * GetVersion: Task to read the Version Information from a specified file
    * SetVersion: Task to modify the Version Information in a specified file
    * UpdateVersion: Task to produces the new values for ASsembly Version, FileVersion, and AssemblyInformationalVersion attributes

### Installation Details
    * create a .build folder under the solution dir
	* Add the ATAP.BuildTooling.CSharp NuGet Package

# msBuild custom targets and tasks from MSBuild Community project
## Tasks
    * Create a file (lockfile)
	* Remove a file (lockfile)

### Installation Details
    * create a .build folder under the solution dir
	* Add the Community Tools NuGet Package

# How to distribute cross-framework custom tasks via NuGet for cro

[Shipping a cross-platform MSBuild task in a NuGet package](https://natemcmaster.com/blog/2017/07/05/msbuild-task-in-nuget/)

# Custom PowerShell scripts for Visual Studio


### Installation Details
    * create a .build folder under the solution dir
	* Add the ATAP.BuildTooling.PPowerShell NuGet Package

# Useful utility programs outside of Visual Studio

## MSbuild Structured log viewer *** Unstable for VS 2018 15.8.9
MSbuild logging can be turned on for visual studio with the vsix package

https://marketplace.visualstudio.com/items?itemName=VisualStudioProductTeam.ProjectSystemTools

MSBuild logs are written to
`C:\Users\<username>\AppData\Local\Temp AKA %APPDATA%\Local\Temp`  (cmd.exe) or `"$Env:AppData\Local\Temp"` (PowerShell)

### Installation Details
Use Chocolatey
[MSBuild Structured Log Viewer](https://chocolatey.org/packages/msbuild-structured-log-viewer)

choco install msbuild-structured-log-viewer
