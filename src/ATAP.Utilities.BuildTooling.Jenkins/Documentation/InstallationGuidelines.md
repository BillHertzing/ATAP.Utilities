# Installation Instructions

## PreRequisites

* Windows 10 or higher
* Powershell Core 7 or higher
* Java Development Kit or runtime. Must be either Java 1.8 or Javaa 11

### Jenkins Service account and password

The computer running Jenkins will need a local user (service account) under whihc the jenkins service will run.

I chose `JenkinsServiceAcct` and password `Notsecret`. ToDo: implement Secrets file for recording the JenkinsServiceAccount password for each machine running Jenkins
next the user must be granted the `logon as a service` right. use gpedit.msc, drill down on ` Computer Configuration\Windows Settings\Security Settings\Local Policies\User Rights Assignment\Log on as a service` and add the `JenkinsServiceAcct` to the existing list of users

## Download Jenkins

Go to [Jenkins Download Page](https://www.jenkins.io/download/) and select Windows, then select the Long-Term Support version of the installer listed there.
Download it (and scan it for malware).
Install it from the .msi download file
  Service Login Credentials:
  A) First Time and/or simple: Use your own local machine's login credentials
  B) More Advanced: Create a new account on your local machine to be the user under whom Jenkins will run
  C) Domain-users: Ask the domain administrators to create a domain-wide account under which Jenkins will run

Port Number: The default is the ubiquitous 8080, soo use something else. I used 4040; The important things is that none of the other applications or services on the local machine use that port
  Whichever port you chose, the local machine's firewall has to be modified to allow port (e.g. 4040) be opened for TCP traffic incoming.

Java Home directory: Enter the path to the directory where Java is installed. Mine was `C:\Program Files\Java\jdk1.8.0_291\`

Selected components: Here you can select the option to open the firewall. I chose not to allow the firewall excpetion here, as I prefer to explicitly manage my local firewall.

Troubleshooting: The installer will attempt to install the `jenkins` service and start it. If it fails to start, to into the Services applet,find the service, inspect its Logon properties, and re-enter the password;

The final step, the installer will open the default browser to the jenkinbs login page , using `localhost:4040/login`
