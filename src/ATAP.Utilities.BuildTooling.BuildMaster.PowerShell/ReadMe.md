# ATAP.Utilities.BuildTooling.BuildMaster.PowerShell

BuildMaster application, release, pipeline, and promotion automation extracted from
the `ATAP.Utilities.BuildTooling.PowerShell` compatibility parent.

## Purpose

Public BuildMaster automation commands are in `public/`; focused Pester tests are in
`tests/Unit/`. This child is independently buildable and remains a required module of
the parent, which continues to re-export the legacy command surface for installed
parent-only consumers.

Version 0.1.2 corrects the BuildMaster Application Management API contract:
the local `Default` artifact sentinel is omitted, only server-supported artifact
values are sent, AssetDirectory requires its paired directory, optional fields
are omitted unless intentionally supplied, and create/update validation details
are surfaced without exposing the API key. The application comparison is
case-insensitive across API property names, preserving idempotent re-entry.

## Functional area

This module belongs to the [PowerShell Build & Packaging](../../SolutionDocumentation/PowerShell-Modules-Build-Process.md)
functional area. The parent-and-child topology is documented in
[BuildToolingFamilyArchitecture.puml](../ATAP.Utilities.BuildTooling.PowerShell/Documentation/BuildToolingFamilyArchitecture.puml).

## Related files

- [INDEX.md](INDEX.md) lists the module's navigable content.
- [ReleaseNotes.md](ReleaseNotes.md) records published behavior changes.
