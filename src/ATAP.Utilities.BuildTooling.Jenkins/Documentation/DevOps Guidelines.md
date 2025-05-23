# Devops Guidelines

How to use the ATAP.Utilities.BuildTooling.Jenkins pipelines and tools in a Windows environment

## Overview

[Build Continuous Integration with Jenkins in C#](https://developer.okta.com/blog/2019/07/26/jenkins-continuous-integration-csharp-aspnetcore)

## Conventions

An ATAP Utilities Jenkins pipeline has a lot of options. All have a default value, and all can be override at multiple levels.

## Dotnet Core ConfigurationRoot

Configuration is handled by creating a Configuration root object. ToDo: Insert link to MS documentation.

```Plantuml
@startStandardConfigurationRoot

Container ATAPStandardConfigurationRoot
  Compiled-in defaults
  Production Settings File
  Environment-specific Settings File
  Production Environment Variables
  Environment-specific Environment Variables
  Production command line arguments and switchmaps
  Environment-specific command line arguments and switchmaps

Container StringConstants
  Each configuration key:value has a string for the key 'ConfigRootKey', and a string for the value 'ConfigRootDefaultValue

ProgramSnippet Access to the data
  From Powershell scripts
    $settings.GetValue<string>(XYZConfigRootKey, XYZConfigRootKey)
  From Groovy scripts
    ToDo:

Creating ConfigurationRoot
  ToDo: Using the ATAPStandardConfigurationBuilder

Injecting ConfigurationRoot
  ToDo: Provide access to a ConfigurationRoot to all stages


@endStandardConfigurationRoot
```

## Creating the BuildTooling.PowerShell

This module holds most of the Powershell functions used by the developers and the CI/CD pipeline steps. During the development of a new feature used by developers, the pipelines, or the end users, module development takes place in parallel with pipeline development to add new stuff to the Product

we publish Powershell packages, src, documentation and optionally tests and localization, via nuget packages, PSGallery, and the chocolatey package manager. Chocolatey and the installation script cooperate to set the package installation location and append the information to the system or user PATH environment variable.

ToDo: Once installed, the path to the executable must be supplied to the database under the key for the machine name. See the ATAP Utilities packages for computer hardware, software, and processes for the data structures to record necessary information.

## Installing powershell modules on DevOps machines

Powershell modules can be installed using Filesystem, NuGet, PowershellGet, or ChocolateyGet package providers.

The Uri for every permutation of is found at:

- `$global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']]`

DevOps machines are considered 'production' unless specifically assigned a development or test role. As such, all DevOps production machines should use only production modules. All machines in the enterprise should get their software packages from approved internal PackageRepositories. Using the publicly published modules ensures that internally, the DevOps machines use the same code that the public uses.

The PackageSource Uri for the Released PackageVersions of ProductionPackage modules are found in found under the subkeys:

- `$global:configRootKeys['PackageRepositoryInternalReleasedNuGetProductionPackagePullUriConfigRootKey']`
- `$global:configRootKeys['PackageRepositoryInternalReleasedChocolateyGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalReleasedPowershellGetProductionPackagePullUriConfigRootKey']`.

The PackageSource Uri for the Released PackageVersions of QualityAssurancePackage modules are found under the subkeys:

- `$global:configRootKeys['PackageRepositoryInternalReleasedNuGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalReleasedChocolateyGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalReleasedPowershellGetQualityAssurancePackagePullUriConfigRootKey']`

Production PackageVersions of modules that are published only internally, not for general public consumption, can also be found under the subkeys:

- `$global:configRootKeys['PackageRepositoryInternalReleasedFilesystemProductionPackagePathNameConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryInternalReleasedFilesystemQualityAssurancePackagePathNameConfigRootKey']`

The (External / Public) Production repositories for Released PackageVersions are at: Chocolatey Community Packages, PSGallery, NuGet. The PackageSource Uri for these can be found under the subkeys:

- `$global:configRootKeys['PackageRepositoryExternalReleasedNuGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalReleasedChocolateyGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalReleasedPowershellGetProductionPackagePullUriConfigRootKey']`

The (External / Public) Production repositories for Prerelease PackageVersions are varied, but there are a number of common ones at: TBD

Prerelease PackageVersions can be pushed to external PackageRepositories for Prerelease PackageVersions like TBD.
The PackageSource Uri for the the Prerelease PackageVersions of the QualityAssurance and Production packages are under the subkeys:

- `$global:configRootKeys['PackageRepositoryExternalPrereleaseNuGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleasePowershellGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleaseChocolateyGetProductionPackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleaseNuGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleasePowershellGetQualityAssurancePackagePullUriConfigRootKey']`,
- `$global:configRootKeys['PackageRepositoryExternalPrereleaseChocolateyGetQualityAssurancePackagePullUriConfigRootKey']`,

Ansible is responsible for ensuring that all host's `$global:Settings` are correct for that host's roles.

### Using NuGet Provider

NuGet configuration file listing the available NuGet package sources is nuget.config, located in the filesystem at the base of all development respoitories. Every DevOps machine that will use the NuGet package provider for pulling or pushing packages needs a copy of this file. The contents of this file should match the values found in `$global:settings[$global:configRootKeys['PackageRepositoriesCollectionConfigRootKey']]`
see also [Common NuGet configurations:Config file locations and uses](https://learn.microsoft.com/en-us/nuget/consume-packages/configuring-nuget-behavior#config-file-locations-and-uses)

The IAC (official) version is stored in "C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.BuildTooling.PowerShell\Resources\NuGet.Config". After installing the module to machine scope using the production package from the ChocolateyGet provider, the installation will create a symbolic link from the installed NuGet.Config in the Resources subdir, to the root of the repository(s). Manually this looks like

```Powershell
# During Development
Remove-Item -path (join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'NuGet.Config') -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -path (join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'NuGet.Config') -Target (join-path $([Environment]::GetFolderPath("MyDocuments")) 'GitHub' 'ATAP.Utilities','src','ATAP.Utilities.BuildTooling.PowerShell','Resources','NuGet.Config')
# After an IAC intervention
# IAC will ensure the machin conforms to the NuGet client role. The NuGet client role will install a custom NuGet.config
#  file in the default machine path, so it will provide the lowest level of the config stack

```

### Using PowershellGet provider

[Unofficial example of PowerShellGet-friendly package. How to create, publish and use](https://github.com/anpur/powershellget-module)

`Install-Module '<ModuleName>' -Scope CurrentUser`

ToDo: Once installed, the path to the module must be supplied to the database under the key for the machine name. See the ATAP Utilities packages for computer hardware, software, and processes for the data structures to record necessary information.

The module contains Functions, and also information about the expected environment variables the Function might use, and argument documentation

ToDo: Find a tool that reads FunctionHelp blocks and turns them into HTML pages. Ask the DocFx folks?

### Using the Chocolatey provider

## Certificates

<https://stackoverflow.com/questions/21076179/pkix-path-building-failed-and-unable-to-find-valid-certification-path-to-requ>

https://stackoverflow.com/questions/63482370/unable-to-find-a-valid-certification-path-to-requested-target

https://www.risual.com/2018/04/handy-certificate-powershell-commands/

https://docs.microsoft.com/en-us/powershell/module/pki/new-selfsignedcertificate?view=windowsserver2019-ps

http://vcloud-lab.com/entries/powershell/powershell-generate-self-signed-certificate-with-self-signed-root-ca-signer

https://pleasantsolutions.com/info/pleasant-password-server/b-server-configuration/2-certificates/lets-encrypt-free-certificates

https://pleasantsolutions.com/info/pleasant-password-server/b-server-configuration/2-certificates/setting-up-a-self-signed-certificate

## Secrets

- Jenkins Agent has a secret, stored in `secret-file`, in the `Custom Workdir Path`. Set the `CustomWorkDirPath` in the Jenkins `Dashboard -> Nodes -> <nodeName> -> Configure -> Launch Method -> Custom WorkDir Path` (e.g `C:\JenkinsAgentNode\<nodename>\` on the agent computer)

## Jenkinsfile

## Visual Studio Code formatter for jenkinsfile

ToDo: install a formatter for Jenkinsfile

## Installing an agent

### Getting the Controllers Instance ID

You can also capture the value by visiting the Instance Identity page, at something like "https://myjenkins.example.com/instance-identity".

### Configuring the Agent as a Windows Service using WinSW

[Jenkins : Installing Jenkins as a Windows service](https://wiki.jenkins.io/display/JENKINS/Installing+Jenkins+as+a+Windows+service)

[How to install Windows agents as a service?](https://support.cloudbees.com/hc/en-us/articles/217423827-How-to-Install-Several-Windows-Slaves-as-a-Service-)
[Windows Service Wrapper in less restrictive license](https://github.com/winsw/winsw/blob/master/doc/installation.md#winsw-installation-guide)

Name of Windows User account used to run the Jenkins Controller service is `JenkinsControllerSrvAcc`, password is stored as a secret somewhere (toDo: Create secrets files (encrypted) somewhere on dropbox not in github). Temporary value is `NotSecret`

Name of Windows User account used to run the Jenkins Agent service is found in the setting `$($global:settings[$global:configRootKeys['JenkinsAgentServiceAccountConfigRootKey']])`, password Temporary value is `NotSecret`, used in the service as "LogOnAs"

- Download the WinSW executable, and rename it to `JenkinsAgent-<Client Version>-<DotNetDesktopframeworkVersion>.exe`
- Create the file `JenkinsAgent-<Client Version>-<DotNetDesktopFrameworkVersion>.xml`, populate it as follows:

```xml
<service>
  <id>JenkinsAgent</id>
  <name>Jenkins Agent</name>
  <description>This service runs an agent for Jenkins automation server.</description>
  <executable>java.exe</executable>
  <arguments>-Xrs -jar &quot;"C:\JenkinsAgentNode\utat022Node\agent.jar"&quot; -jnlpUrl http://utat022:4040/computer/utat022Node/jenkins-agent.jnlp -secret 925f7db2725b5a2c1d72d4289439ba848fdd934b59e4722694f72081c56618b7 -workDir "C:\JenkinsAgentNode"</arguments>
  <logmode>rotate</logmode>
  <onfailure action="restart">
    <download from=" http://utat022:4040/jnlpJars/slave.jar" to="%BASE%\jenkins-client.jar">
      <extensions>
        <extension className="winsw.Plugins.RunawayProcessKiller.RunawayProcessKillerExtension" enabled="true" id="killOnStartup">
          <pidfile>%BASE%\jenkins_agent.pid</pidfile>
          <stopTimeout>5000</stopTimeout>
          <stopParentFirst>false</stopParentFirst>
        </extension>
      </extensions>
    </download>
  </onfailure>
<serviceaccount>
  <domain>utat022</domain>
  <user>JenkinsAgentSrvAcct</user>
  <password>NotSecret</password>
  <allowservicelogon>true</allowservicelogon>
</serviceaccount>
</service>
```

Note that the Java.exe does not specify a path. Instead it will use the first java.exe found in the process's `$env:Path`. This is based on the machine profile and the user profile for `JenkinsAgentSrvAcct`
The configuration specifies that the agent jar file is found exactly at
The jnlpURL argument is using http (TBD switch to https when Jenkins Controller is configured with a SSL certificate)
The 'secret' comes from the node configuration page
The WorkDir should depend on the current node's global settings

Start an administrator Powershell terminal session
Change to the directory `C:\JenkinsAgentNode` and run the command `.\Jenkins-client-2.9.0-net461.exe Install` (use `.\Jenkins-client-2.9.0-net461.exe Uninstall` first, if a service already exists and you are chaning its configuration)

## Starting an Agent from the command line

[Launching inbound agents](https://github.com/jenkinsci/remoting/blob/master/docs/inbound-agent.md)

This command can be configured, then run via any shell, on the server where the agent service is expected to run

```Text
java -cp agent.jar hudson.remoting.jnlp.Main \
  -headless \
  -workDir <work directory> \
  -direct <HOST:PORT> \
  -protocols JNLP4-connect \
  -instanceIdentity <instance identity> \
  <secretString> <agentName>
```

Or this

```Text
echo <secret key> > secret-file
java -jar agent.jar -jnlpUrl <jnlp url> -secret @secret-file -workDir <work directory>
```

Or this

```Text
java -jar agent.jar \
  @agent_options.cfg
```

With an `agent_options.cfg` file containing

```Text
-jnlpUrl
<jnlp url>
-secret
<secret key>
-workDir <work directory>
```

## Cleanup failed runs

[Jenkins Pipeline Wipe Out Workspace](https://stackoverflow.com/questions/37468455/jenkins-pipeline-wipe-out-workspace)

```Groovy
pipeline {
    agent { label "master" }
    options { skipDefaultCheckout() }
    stages {
        stage('CleanWorkspace') {
            steps {
                cleanWs()
            }
        }
    }
}
```

Follow these steps:

1. Navigate to the latest build of the pipeline job you would like to clean the workspace of.
1. Click the Replay link in the LHS menu.
1. Paste the above script in the text box and click Run

Also try variations on the below script... Will work for default workspace as well

TBD use CustomWorkDirPath instead of hardcoded.

```Groovy
pipeline {
    agent {
        node {
            customWorkspace "/home/jenkins/jenkins_workspace/${JOB_NAME}_${BUILD_NUMBER}"
        }
    }
    post {
        cleanup {
            /* clean up our workspace */
            deleteDir()
            /* clean up tmp directory */
            dir("${workspace}@tmp") {
                deleteDir()
            }
            /* clean up script directory */
            dir("${workspace}@script") {
                deleteDir()
            }
        }
    }
}

```

## Build Code stage

If the Artifacts contain one or more Powershell modules being, the <modulename>.psd1 file must be generated by the build script. Then the build script must generate the NuGet package for the module, and push it to the file based local feed. The testing steps will include unit and integration tests to ensure the package is created correctly, and the package cmdlets and other contents pass their tests.

Resource files have to be generated by a build stage, from the .resx files in a project's directory

Executable code, either .dll or .exe files, that are expected to run **As Services** under Core on Linux and Windows, must be built with specific RunTimeIdentifiers. The normal _dotnet build_ has to be in a loop across all supported RIDs

Executable code being built has to be built inside a loop that calls the build with each supported TargetFramework, although for many TargetFramework values, the build specification file itself (the .csproj file and the Directory.Build.props and directory.Build.targets files it includes) can take care of this by specifying TargetFrameworks ad a list of target frameworks to build against

### dotnet build stage

#### Detailed logs of the build process

- [MSBuild Structured Log](https://github.com/KirillOsenkov/MSBuildStructuredLog) is a logger for creating detailed logs of the build process
- [StructuredLogger Nuget package](https://www.nuget.org/packages/MSBuild.StructuredLogger/2.1.507)

1. Install the package as part of the .csproj file
2. add the switch /logger:BinaryLogger,"packages\MSBuild.StructuredLogger.2.1.507\lib\netstandard2.0\StructuredLogger.dll";"C:\Users\SomeUser\Desktop\binarylog.binlog"

ToDo: version control? hardcoded version number in switch?

## PlantUmlClassDiagramGenerator stage

[PlantUmlClassDiagramGenerator](https://www.nuget.org/packages/PlantUmlClassDiagramGenerator)

### prerequisites

ToDo: Move into prerequisites step of the pipeline, test for installed and minimum required version

dotnet tool install --global PlantUmlClassDiagramGenerator

### command line

```powershell
puml-gen "./" "./" -dir -createAssociation -excludePaths "bin,obj,Properties"
```

## "'Test' stage"

### dotnet test command

[dotnet test](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-test)

### Optimizations

Since the Jenkinsfile has already built the code and the tests, add the following arguments `--nologo --no-restore --no-build`

### Where to find the binaries to run

--output <OUTPUT_DIRECTORY> defaults to default path is ./bin/<configuration>/<framework>/ but ATAP Standard ?todo:? Expects a `Published` directory to be the location . From within test code methods , ` AppDomain.BaseDirectory` will return the location from which the tests are running

### Where to put the test results

--results-directory <RESULTS_DIR> default is `TestResults` subdirectory in the `_generated` subdirectory alongside the project file

### Runtime Identifier

-runtime <RUNTIME_IDENTIFIER> - Important for tests that validating a portion of the code that installs as a service, different RIDs for Windows, Linux, and MacOS. Validate all the dll and executable code exists for each RID, and validate that the files in each group do indeed have the metadata that identifies the RID it was built against.

### Build configuration

The build stage should loop over each value of the configuration list \<Debug>,\<Production>,\<ProductionWithTrace> and build the .dll and .exe files once with each value

--configuration <CONFIGURATION> - defaults to `Debug`

### Code Coverage

Install [Coverlet](https://github.com/coverlet-coverage/coverlet)

[Use code coverage for unit testing](https://docs.microsoft.com/en-us/dotnet/core/testing/unit-testing-code-coverage?tabs=windows#code-coverage-tooling)

`--collect:"XPlat Code Coverage"` option to `dotnet test`

### Loggers

### Runssettings arguments passed via command line

### Runsettings files

## Documentation Generation

The stage needs a step that moves the readme.html over to index.html, renames any generated assets located in \_site/Assets/\*, and reworks the asset links from readme to index

The post build cleanup stage should include a step that removes generated `.puml` files from directories where a source file contains the source of the diagram.

ToDo: Better would be to put all generated files in a tree structure located somewhere below \_generated, and then convert each to an asset and write that asset to the correct subdir under \_site/assets, such that the subdir matches the subdir where the source code was found

C2Plantuml puts one .puml file for each class/interface/etc. found in a compilation unit into the directory alongside the compilation unit. ToDo: move these to a identical tree under \_generated. Convert each to an asset and put them into the correct subdir under \_site/assets. Have a build step create a `<compilationunit>.md file, and populate it with a link between each svg asset and the original source code file from which it was generated
