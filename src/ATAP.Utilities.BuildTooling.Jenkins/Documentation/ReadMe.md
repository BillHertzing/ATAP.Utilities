# Landing Page for ATAP.Utilities.BuildTooling.Jenkins Conceptual Documentation

## Overview
This package contains the ATAP Utilities Jenkins library modules and a Jenkinsfile template.

## Controlling Jenkins

Jenkins runs as a Windows service. Te Jenkins service may, at almost any time, be busy running jobs. To cleanly shutdown Jenkins, we need to tell it to stop accepting new jobvs, finish any running jobs, and/or/terminate certain jobs, then stop the service.


Attributions:

[Jenkins Configuring HTTP} 9https://www.jenkins.io/doc/book/installing/initial-settings/#configuring-http] - Instructions for building/installing/using a HTTPS certificate for Jenkins on Windows

[Jenkins URL commands](http://[jenkins-server]/exit) This page shows how to use URL commands.

http://yourjenkins/quietDown - Keep current jbs running but disallow any new ones
http://[jenkins-server]/exit - To shutdown

(Administering Jenkins](https://wiki.jenkins.io/display/JENKINS/Administering+Jenkins) - Backup / restore; Copy/Move/Rename jobs; Jenkins directory structure; exit/restart/reload URL commands

