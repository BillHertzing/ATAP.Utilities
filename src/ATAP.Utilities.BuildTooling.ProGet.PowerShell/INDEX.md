# ATAP.Utilities.BuildTooling.ProGet.PowerShell index

- `ATAP.Utilities.BuildTooling.ProGet.PowerShell.psd1` — module manifest and family dependencies.
- `ATAP.Utilities.BuildTooling.ProGet.PowerShell.psm1` — source loader.
- `public/` — exported ProGet, package-signing, promotion, synchronization, and install commands plus file-local helpers.
- `private/` — ProGet endpoint, feed-type, package-import, and pre-promotion signature helpers.
- `tests/` — focused unit and integration coverage for the extracted surface.
- `Documentation/` — module-specific documentation.
- `public/Set-PSModuleFileSignature.ps1` — signs staged PowerShell files by certificate-store thumbprint and timestamps every signature.
- `public/Test-PSModulePackageSignature.ps1` — fails closed on unsigned, invalid, or untimestamped package content and writes public metadata evidence.
- `public/Sync-ProGetPowerShellModules.ps1` — compares installed modules with a configured or explicit ProGet feed and installs only missing or newer versions.
- `Documentation/Sync-ProGetPowerShellModules.md` — operator contract, safety boundaries, examples, and verification notes for module synchronization.
