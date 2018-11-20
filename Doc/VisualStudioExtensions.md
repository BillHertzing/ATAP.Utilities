<h1> Visual Studio settings and Extensions needed to build ATAP.Utilities solution and project</h1>

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
	
# Custom PowerShell scripts for Visual Studio


### Installation Details
    * create a .build folder under the solution dir
	* Add the ATAP.BuildTooling.PPowerShell NuGet Package

