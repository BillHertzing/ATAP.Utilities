# Devops Guidelines

How touse the ATQAP.Utiliites..BuildTooling.Jenkins pipelines and tools in a Windows environment

## Overview

https://developer.okta.com/blog/2019/07/26/jenkins-continuous-integration-csharp-aspnetcore


## Conventions

An ATAP Utilities Jenkins pipeline has a lot of options. All have a default value, and all c an be override at multiple levels.

## Dotnet Core ConfigurationRoot

Configuration is handeled by creatiug a Configuration root object.  ToDo: Insert link to MS documentation.

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

## Certificates

https://stackoverflow.com/questions/21076179/pkix-path-building-failed-and-unable-to-find-valid-certification-path-to-requ

https://stackoverflow.com/questions/63482370/unable-to-find-a-valid-certification-path-to-requested-target

https://www.risual.com/2018/04/handy-certificate-powershell-commands/

https://docs.microsoft.com/en-us/powershell/module/pki/new-selfsignedcertificate?view=windowsserver2019-ps

http://vcloud-lab.com/entries/powershell/powershell-generate-self-signed-certificate-with-self-signed-root-ca-signer

https://pleasantsolutions.com/info/pleasant-password-server/b-server-configuration/2-certificates/lets-encrypt-free-certificates

https://pleasantsolutions.com/info/pleasant-password-server/b-server-configuration/2-certificates/setting-up-a-self-signed-certificate

## Secrets

## Jenkinsfile

## Visual Studio Code formatter for jenkinsfile

ToDo: install a formatter for Jenkinsfile

## Installing an agent

### Getting the Controllers Instance ID:
ou can also capture the value by visiting the Instance Identity page, at something like "https://myjenkins.example.com/instance-identity".

### Configuring the Agent as a Windows Service

https://wiki.jenkins.io/display/JENKINS/Installing+Jenkins+as+a+Windows+service

https://support.cloudbees.com/hc/en-us/articles/217423827-How-to-Install-Several-Windows-Slaves-as-a-Service-

## Starting an Agent

https://github.com/jenkinsci/remoting/blob/master/docs/inbound-agent.md

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

https://stackoverflow.com/questions/37468455/jenkins-pipeline-wipe-out-workspace


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

1) Navigate to the latest build of the pipeline job you would like to clean the workspace of.
1) Click the Replay link in the LHS menu.
1) Paste the above script in the text box and click Run


Also try variations on the below script... Will work for default workspace as well
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

## Build stage

### dotnet build stage

#### [MSBuild Structured Log](https://github.com/KirillOsenkov/MSBuildStructuredLog) is a logger for creating detailed logs of the build process

 [StructuredLogger Nuget package](https://www.nuget.org/packages/MSBuild.StructuredLogger/2.1.507)

1) Install the package as part of the .csproj file
2) add the switch /logger:BinaryLogger,"packages\MSBuild.StructuredLogger.2.1.507\lib\netstandard2.0\StructuredLogger.dll";"C:\Users\SomeUser\Desktop\binarylog.binlog"

ToDo: version control? hardcoded version number in switch?

## CodeTOPlantUML stage

### prerequisites

ToDo: Move into prerequisites step of the pipeline, test for installed and minimum required version
https://www.nuget.org/packages/PlantUmlClassDiagramGenerator
dotnet tool install --global PlantUmlClassDiagramGenerator

### command line
Foreach ($srcprojdir in $srcprojdirs)
puml-gen $srcprojdir $srcprojdir/Documentation/_generated/PlantUML -dir  -createAssociation


## "'Test' stage"

#dotnet test command

https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-test

### OPtimizations:

Since the Jenkinsfile has already built the code and the tests, add the following arguments `--nologo --no-restore --no-build`

### Where to find the binaries to run

--output <OUTPUT_DIRECTORY>  defaults to default path is ./bin/<configuration>/<framework>/  but ATAP Standard ?todo:? Expects a `Published` directory to be the location . From within test code methods , ` AppDomain.BaseDirectory` will return the location from whihc the tests are running

### Where to put teh test results

--results-directory <RESULTS_DIR>   default is `TestResults` subdirectory in the directory that contains the project file

### Runtime Identifier

-runtime <RUNTIME_IDENTIFIER>  - Important for tests that validating a portion of the code that installs as a service, different RIDs for Windows, Linux, and MacOS

### Build configuration

--configuration <CONFIGURATION>  - defaults to `Debug`

###  Code Coverage

Install [Coverlet]()

`--collect:"XPlat Code Coverage"` option to `dotnet test`

### Loggers

### Runssettings arguments passed via command line



### Runsettings files
