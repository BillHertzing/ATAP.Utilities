# Administrator-Only Holding Pen

Temporary location for scripts that contain `#Requires -RunAsAdministrator`.

These files are intentionally outside normal module roots so non-elevated module
import, build, and promoted-package test runs can proceed. They should move into
a dedicated administrator-focused module once that module boundary is defined.

Current holdings:

- `ATAP.Utilities.PowerShell/public/New-LocalServiceAccount.ps1`
- `ATAP.Utilities.PowerShell/tests/Unit/New-LocalServiceAccount.Tests.ps1`
- `ATAP.Utilities.DatabaseManagement.Powershell/archive/New-SqlWinScheduledTasks.ps1`
