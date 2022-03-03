# Powershell Useage in ATAP.Utilities

## OVerview of this document

powershell is widelyused in the delivered ATAP.Utility packages, both as libraries of functions and cmdlets that cna be utilized in end-user software, and as build tooling used to creeate the developer and CI experience. This documejnt outlines many of the conventions used in developing the Powershell packages and tools

## Powershell Desktop (currently V5) vs Powershell Core (currently V7)

Mostly written for V7 Cross-platform

## Settings

## Join-Path instead of path strings

## [Environment] instead of $env

## Using classes defined in Powershell Modiles

Since the AATAP.Utilities rpository contains a robust CI pipeline, it is very feasable to write the classes and enumerations in c# and targeting .Net (cross-platofrm), compile them to a .dll, and include them in a package. That way, other modules that want to work with the smae classes and enumerations can simply include the .dlls exported by the module. (ToDo: Check this works as explained)


The following two seemed a good idea, but the work has languished.

[How to write Powershell modules with classes](https://stephanevg.github.io/powershell/class/module/DATA-How-To-Write-powershell-Modules-with-classes/)

[PSClassUtils](https://github.com/Stephanevg/PSClassUtils)


### Package structure




