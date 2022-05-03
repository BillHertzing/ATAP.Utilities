# Installation Instructions

## PreRequisites

* Windows 10 or higher
* Powershell Core 7 or higher
* Java Development Kit or runtime. Must be either Java 1.8 or Javaa 11

### Jenkins Service accounts and password

#### Jenkins Controller service account

The machine running the Jenkins Controller needs a local user (service account) under which the Jenkins Controller service will run.
   run `lusrmgr. msc`

I chose `JenkinsServiceAcct` and password `Notsecret`. ToDo: implement Secrets file for recording the JenkinsServiceAccount password for each machine running Jenkins

Create the new user via `Computer Management->Local Users And Groups->Users->New User`

The `JenkinsServiceAcct` must be granted the `logon as a service` right. use `gpedit.msc`, drill down on ` Computer Configuration\Windows Settings\Security Settings\Local Policies\User Rights Assignment\Log on as a service` and add the `JenkinsServiceAcct` to the existing list of users

#### Jenkins Controller service account

Every machine in the cluster that runs a Jenkins build agent needs a local user (service account) under which the Jenkins Agent service will run.

I chose `JenkinsAgentSrvAcct` and password `NotSecret`. ToDo: implement Secrets file for recording the JenkinsServiceAccount password for each machine running Jenkins

Create the new user via `Computer Management->Local Users And Groups->Users->New User`

The `JenkinsAgentSrvAcct` must be granted the `logon as a service` right. Run `gpedit.msc`, drill down on `Computer Configuration\Windows Settings\Security Settings\Local Policies\User Rights Assignment\Log on as a service` and add the `JenkinsServiceAcct` to the existing list of users

### Subdirectories to be created

#### Controller Subdirectories

The Controller service will create a subdirectory called `Jenkins` under the path `$env:AppDataLocal`  for the Controller Service account, e.g. `C:\Users\JenkinsServiceAcct\AppData\Local\Jenkins`

#### Agent Subdirectories

The Agent service will create a subdirectory called `Jenkins` under the path `$env:AppDataLocal`  for the Agent Service account, e.g. `C:\Users\JenkinsAgentSrvAcct\AppData\Local\Jenkins`
Create C:\JenkinsAgentNode

### Nodes


## Download Jenkins

Go to [Jenkins Download Page](https://www.jenkins.io/download/) and select Windows, then select the Long-Term Support version of the installer listed there.
Download it (and scan it for malware).
Install it from the .msi download file
  Service Login Credentials:
  A) First Time and/or simple: Use your own local machine's login credentials
  B) More Advanced: Create a new account on your local machine to be the user under whom Jenkins will run
  C) Domain-users: Ask the domain administrators to create a domain-wide account under which Jenkins will run

Port Number: The default is the ubiquitous 8080, so use something else. I used 4040; The important things is that none of the other applications or services on the local machine use that port
  Whichever port you chose, the local machine's firewall has to be modified to allow port (e.g. 4040) be opened for TCP traffic incoming.

Java Home directory: Enter the path to the directory where Java is installed. Mine was `C:\Program Files\Java\jdk1.8.0_291\`

Selected components: Here you can select the option to open the firewall. I chose not to allow the firewall excpetion here, as I prefer to explicitly manage my local firewall.

Troubleshooting: The installer will attempt to install the `jenkins` service and start it. If it fails to start, to into the Services applet,find the service, inspect its Logon properties, and re-enter the password;

The final step, the installer will open the default browser to the Jenkins login page , using `localhost:4040/login`

## Jenkins Environment variables

see also [Using environment variables](https://www.jenkins.io/doc/book/pipeline/jenkinsfile/#using-environment-variables)

[https://phoenixnap.com/kb/jenkins-environment-variables](Jenkins Environment Variables: Ultimate Guide)

### The Jenkins Environment variables for the master Jenkins controller

`JENKINS_HOME` is only set on a a computer where the Jenkins Controller is running.

The URL for the Jenkins master server is `JENKINS_URL`, and should be set for every computer that participates in the Jenkins pipeline. The value should be the same as configured in the jenkins master configuration, for example `http://<DNS-resolvable-hostname>:<PortNumber>`.
I have setup jenkins controller running on port `4040` (becasue `8080` is too widely used as the default by many other http-accessible application)

### Environment variables for using the Jenkins-CLI

1) `JENKINS_USER_ID` set to a username that is configured in Jenkins Security

1) `JENKINS_API_TOKEN` set to a Jenkins API token associated with a Jenkins user


## Jenkins Agents

Identify the machines in the cluster which will run Jenkins Agents, and which pipeline steps can be run on which machine

### Setup Jenkins Agent nodes

#### Clean install

  Configure Jenkins, add new nodes
  Allow nodes to connect with jnlp protocol

#### Migration
 copy content of `nodes` subdirectory
 add/delete noed (directories) as required
 Allow nodes to connect with jnlp protocol


### JenkinsSharedLibraries

Add ATAPCommonJenkinsLibrary.groovy as a shared library (ToDo: point to an installed package, until then, point to the src code in the repository)

#### Clean install

#### Migrate

## Modify Jenkins to use SSL



Edit the file `jenkins.xml` in the `$env:JENKINS_HOME` directroy. Find the line `-httpPort:4040` (substitute the port your Jenkins Controller is listening to), and replace `-httpPort:4040` with `-httpPort:4040 -httpsPort:4041`. Restart the Jenkins controller service
