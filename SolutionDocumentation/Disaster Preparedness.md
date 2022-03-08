 
# Disaster Preparedness for Development,  CI/CD, and Products

If you are viewing this `Disaster Preparedness.md` in GitHub, [here is this same Disaster Preparedness on the documentation site]()

## <a id="Introduction" />Introduction

What happens to productivity when disaster strikes the organization's computer resources? Flooding in a datacenter, fire in the developer's offices, malware infections, alien invasion - the list could go on and on. Disaster preparedness and disater recovery planning / practice are keys to ensuring that the producitivy loss and product delays are kept to a minimum

## <a id="GettingStarted" />Getting Started

The single most important concept around disaster preperation is the idea of having multiple redundant, up-to-date copies of all the information needed to recreate the development tools and processes, the CI/CD tools and process, the databases, and the products themselves

### <a id="Prerequisites" />Prerequisites

#### Cloud storage locations

##### DropBox

##### OneDrive

##### GoogleDrive

#### On-Premise Hot Backup locations

#### Off-Premise Cold Backup locations

## Overview

To prepare for a disaster, every process and tool has information that needs to be preserved prior to a disaster and restored after a disaster. The degree to whihc automatiojn can be applied to "bag" the necessary information, and to "unbag" or "apply" the stored information, determines the effectiveness and efficieny of the disaster recovery efforts

ToDo: Insert diagram of development process, tools, and information to be protected

ToDo: Insert diagram of CI/CD process


## Validating the processes

Having good process defined and implemented iis important. Also important is validating that there are no errors in the tools data.

### Confirm-GitFSCK


## Disaster Preparedness

In the event of a disaster that renders the computers used in the creation of software themselves useless, it is critical that a record is made (and safely stored) of the contents of the settings and configurations of all the tools
## Backup and Restoration of tool's data

Many of the tools used in the development and CI/CD process have settings and configurations. 

### Visual Studio Code

#### settings.json

### Visual Studio Code Extensions

#### Git

Store the remote repository URL and credentials

#### SpellCheck

store the list of exceptions, for each repository workspace and for each user
