# Build Folder

The `Build` folder holds repository-level build support that is not owned by a
single package or module.

Run [Invoke-RepoHealthGate.ps1](Invoke-RepoHealthGate.ps1) as a separate C#
repository-health gate after restore and before pack or publish. It invokes the
Pester tests under `tests/RepoHealth` and is intentionally outside the
PowerShell module package build/test flow.
