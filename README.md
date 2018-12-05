
# ATAP.Utilities
These are a treasure of Projects/Assemblies (at least I hope they will be eventually) for tools, algorithms and concepts, and data structures to make programming life easier. 
  * These libraries are the computational and building core of of ATAP's ACE project and the Blazor-related demos. 
  * This repository includes enhancements to Visual Studio, in the form of MSBuild tooling, including MSBuild Tasks, Targets, and Properties, along with PowerShell Scripts and Modules. 
  * The ReadMe and User Manual  for the projects, along with QuickStarts, Guides and Tutorials.
  * Attributions that refer to articles on using other 3rd party Open Source Software (OSS) and commercial products to make programming withing Visual Studio easier.
  * All the documentation, and the full repository's API, is published via AutoDoc project and DocFx to the repository's documentation site in side the repository and committed to GitHub.
  * The documentation site is made available to the public via GitHub pages. 
  
Further information on the overall contents of this repository can be found in the [detailed documentation for this repository](./SolutionDocumentation/ReadMe.html)

Other detailed documentation you might be interested are 
  * [Building a solution from Visual Studio]()
  * [Building a solution Using MSBuild via a Command Line Interface (CLI)]()
  * [Building a solution using the DotNet build command]()  * []()
  * [Using ATAP BuildTooling to manage Version information]()
  * [Using ATAP BuildTooling PowerShell scripts with Visual studio]()
  * [Using DoxFx to build the ATAP.Utilities documentation website]()
  * [Detailed API Information for the packages in this repository](./API/ReadMe.html)


# Getting started
## Prerequisites
1. Visual Studio (VS) 2017 Version 15.8 or newer. All of the following instructions assume you are using a Visual Studio (VS) 2017 IDE for development. More information on suggested settings and on 3rd party tools and extensions that make development easier is in the [Getting Started guide](./SolutionDocumentation/gettingStarted.html}. If you want to use the ATAP BuildTooling from this repository, see the [ATAP.BuildTooling GettingStarted guide] for additional required Visual Studio extensions and settings. If you want to build the documentation for this repository, or learn more about how the AutoDoc project works, see the [ATAP.Utilities.AutoDoc Getting Started Guide] for instructions. If you are in Building/using these tools outside of Visual Studio, [Building](./SolutionDocumentation/ReadMe.html#Building) provides additional documentation on options for building the demos outside of Visual Studio
1. Familiarity with using Git and GitHub in VS.

## Getting the packages and tools
### Using NuGet to add an ATAP.Utility package to your projects
Help Needed, see issue #30
### Using NuGet to add the ATAP.BuildTooling to your solutions
Help Needed, see issue #31 and issue #32
### Using Chocolatey to add the ATAP.BuildTooling machine-wide
Help Needed, see issue #33 and issue #34
### Getting the source code and further developing the packages
### Forking the repository
The only way at the moment to begin working with the source is to fork the repository, build the packages, and work with your own copy. Here are some instructions on [how to fork a GitHub repository](https://help.github.com/articles/fork-a-repo/).
Once you have forked the repository, attach it to Visual Studio running on your development workstation.
\<insert a reference to instructions on how to connect a GitHub remote repository to Visual studio on a developers workstation>

## Using the Library packages
[Using the ATAP Utility Libraries](./SolutionDocumentation/GettingStarted.html#UsingLibraries)
## Using the ATAP BuildTooling
doxfx output (./ATAP.Utilities.BuildTooling.CSharp/_site/index.html)
## Using the ATAP AutoDoc project
[Using the ATAP Utility AutoDoc](./SolutionDocumentation/GettingStarted.html#UsingAutoDoc)

## Features

What's all the bells and whistles this project can perform?
* What's the main functionality
* You can also do another thing
* If you get really randy, you can even do this



## Contributing

When you publish something open source, one of the greatest motivations is that
anyone can just jump in and start contributing to your project.

These paragraphs are meant to welcome those kind souls to feel that they are
needed. You should state something like:

"If you'd like to contribute, please fork the repository and use a feature
branch. Pull requests are warmly welcome."

If there's anything else the developer needs to know (e.g. the code style
guide), you should link it here. If there's a lot of things to take into
consideration, it is common to separate this section to its own file called
`CONTRIBUTING.md` (or similar). If so, you should say that it exists here.

## Links

Even though this information can be found inside the project on machine-readable
format like in a .json file, it's good to include a summary of most useful
links to humans using your project. You can include links like:

- Project homepage: https://your.github.com/awesome-project/
- Repository: https://github.com/your/awesome-project/
- Issue tracker: https://github.com/your/awesome-project/issues
  - In case of sensitive bugs like security vulnerabilities, please contact
    info@ATAPConsulting.com directly instead of using issue tracker. We value your effort
    to improve the security and privacy of this project!
- Related projects:
  - Your other project: https://github.com/BillHertzing/Ace



## Licensing
The code in this project is licensed under MIT license.
