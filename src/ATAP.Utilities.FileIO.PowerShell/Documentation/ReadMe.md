# ReadMe for the ATAP.Utilities.FileIO.Powershell Concept Documentation

## Overview

Powershell functions focused around local files, directories,and cloud locations

## Testing

TBD

## Packaging and Distribution

ToDo: Write content

## Public Functions and Cmdlets

## Functions that access DropBox

All functions that acess DropBox via the web must be authenticated with a Dropbox access token. The Dropbox access token must be set in the environment for the dropbox functions to work

[System.Environment]::SetEnvironmentVariable('DropBoxAccessToken','<paste token here>',[System.EnvironmentVariableTarget]::User)

### Get-DropBoxFolderList

This function lists (recusivly) the contents of a dropbox folder by quering dropbox


```
