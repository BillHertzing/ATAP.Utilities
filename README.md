![ATAPLogo](https://base_html/pathtologo.png) --ToDo - AltText:Logo for ATAP Technology, IInc.

I am actively developing this documentation static website, and publishing to the ATAP Utilities GitHub Pages host. Over the course of the next few weeks, the site will be in a constant state of flux, but hopefully will settle down after the automation tools are completed and content is written.

# ATAP.Utilities
These are a collection of Projects/Assemblies that provide a variety of data structures and algorithms to make programming life easier. Much of the features of ATAP's ACE project and the Blazor-related demos are implemented in these utilities. This repository includes enhancements to Visual Studio, in the form of MSBuild tooling, including MSBuild Tasks, Targets, and properties, along with PowerShell scripts and Modules. The setup and usage instructions for the projects, along with QuickStarts, Guides and Tutorials for these projects and articles on using other 3rd party Open Source Software (OSS) and commercial products to make programming withing Visual Studio easier are contained in the repository and published to the repository's documentation site, currently hosted in GitHub Pages here: https://billhertzing.github.io/ATAP.Utilities/ATAP.Utilities.AutoDoc/Index.html

Documentation specifically on using the AutoDoc project within this repository to help you create a static documentation website for your repository can be found here. [here](./ATAP.Utilities.AutoDoc/Docs/ReadMe.html)

## Installing / Getting started
### Forking the repository
The only way at the moment is to fork the repository, build the packages, and work with your own copy.
\<insert a reference to instructions on how to Fork a repository in GitHub>
Once you have forked the repository, attach it to Visual Studio running on you development workstation.
\<insert a reference to instructions on how to connect a GitHub remote repository to Visual studio on a developers workstation>
Jump to Initial Configuration

> The following distribution methods are under active development, but not yet released beyond local feed. The extended MSBuild tooling in this Repository is where the development and eventual production code will reside.

>  > ### NuGet 
>  > The individual assemblies are distributed as NuGet packages. The entire repository can be installed via NuGet. There is a NuGet package dedicated to installing just the MSBuild tooling enhancements. There is a NuGet package dedicated to installing just the  AutoDoc project to a repository. Instructions for adding individual assemblies to your projects via NuGet: (tbd)

>  > ### Chocolatey
   > In addition to NuGet, the packages are distributed by Chocolatey. Instructions for getting the MSuild tooling enhancements via Chocolatey: (tbd)
> 

### Initial Configuration
Before you can start building the projects in this repository, or using the NuGet projects, some of these projects require some initial configuration steps. <tbd?>
#### Install the ATAP.Utilities.BuildTooling tools
The BuildTooling utilities are developed in this project, and they are also used by all projects in this repository. So you will need to install these tools before tryinng to build.

Did you know that there are blogs dedicated to helping you write a ReadMe.md file for a GitHub repository?
https://github.com/noffle/art-of-readme
https://github.com/jehna/readme-best-practices
The content below came from the  template in https://github.com/jehna/readme-best-practices

/<placeholder - continue writing repository README from here>

## Developing

Here's a brief intro about what a developer must do in order to start developing
the project further:

```shell
git clone https://github.com/your/awesome-project.git
cd awesome-project/
packagemanager install
```

And state what happens step-by-step.

### Building

If your project needs some additional steps for the developer to build the
project after some code changes, state them here:

```shell
./configure
make
make install
```

Here again you should state what actually happens when the code above gets
executed.

### Deploying / Publishing

In case there's some step you have to take that publishes this project to a
server, this is the right time to state it.

```shell
packagemanager deploy awesome-project -s server.com -u username -p password
```

And again you'd need to tell what the previous code actually does.

## Features

What's all the bells and whistles this project can perform?
* What's the main functionality
* You can also do another thing
* If you get really randy, you can even do this

## Configuration

Here you should write what are all of the configurations a user can enter when
using the project.

#### Argument 1
Type: `String`  
Default: `'default value'`

State what an argument does and how you can use it. If needed, you can provide
an example below.

Example:
```bash
awesome-project "Some other value"  # Prints "You're nailing this readme!"
```

#### Argument 2
Type: `Number|Boolean`  
Default: 100

Copy-paste as many of these as you need.

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
