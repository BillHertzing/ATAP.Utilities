# ReadMe for the ATAP.Utilities.FileIO.Powershell Concept Documentation

## Overview

Powershell functions focused around local files, directories,and cloud locations

## Testing

TBD

## Packaging and Distribution

ToDo: Write content

## Public Functions and Cmdlets

## Functions that access DropBox

All functions that acess DropBox via the web must be authenticated with a Dropbox access token. The Dropbox access token must be set in the environment for the Dropbox functions to work.

(How to get a Dropboc access token)[http://99rabbits.com/get-dropbox-access-token/]

[System.Environment]::SetEnvironmentVariable('DropBoxAccessToken','<paste token here>',[System.EnvironmentVariableTarget]::User)

### Get-DropBoxFolderList

This function lists (recusivly) the contents of a dropbox folder by querying dropbox.

This function is called by te jenkins Job Get-DropboxFolders-Nightly which is scheduled to run at a random time between 3am and 4 am (local)

### Get-DropBoxSharingLink

This function asks DropBox to rturn the URL sharing link to an image. If one does not exist, a request is sent to create a sharing link. Some file permissions can be specified as parameters. The image to be shared is specified as a filename accessible to the local computer that is part of the dropbox hierachy on the local computer. The default value of the tetrameter for the root of the dropbox hierarchy is `c:\dropbox`. This built-in can be overridden with the value of the environment variable $env:($global:configRootKeys['DropBoxBasePathConfigRootKey']). That global variable is set on a per-computer bases by the ATAP profiles and their supporting files. See the `src\ATAP.Utilities.Powershell\Profiles\global_MachineAndNodeSettings.ps1` and `C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.Utilities.Powershell\Profiles\global_ConfigRootKeys.ps1` files.

Defaults:

### Get-ResponsiveImageEmbeddedLink

This function returns an object containing objects and strings that represent the embedded links to place in a blog posts' .md file for embedding responsive images into that post.

Inputs: (pipeline) a single MediaQuery object
Inputs: (non-pipeline and pipelinebyproperty) :
ResponsiveStillImageLinkTemplate
ResponsiveMovingImageLinkTemplate
MovingImageExtensionPattern



```
