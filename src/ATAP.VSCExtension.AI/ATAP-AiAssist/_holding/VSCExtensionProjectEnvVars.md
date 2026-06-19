# Held: `VSCExtensionProject*` Environment Variables

**Status:** Set aside (not active). Earmarked for the future dedicated **AIAssist**
(`ATAP-AiAssist`) repository.

## Why this exists

Sprint 0010, Task 10.24 removed the three `VSCExtensionProject*` environment-variable
definitions from the shared `ATAP.Utilities.PowerShell` profile chain. The whole AIAssist
project is being split out of `ATAP.Utilities` in an upcoming sprint, so these
AIAssist-specific variables were lifted out of the shared profile **now** to keep that
split clean. They are preserved here (not merely deleted) so the future AIAssist repo can
re-establish them in its own profile/setup.

## Definitions (names + values as of removal, 2026-06-19)

These were set at **User** scope (`[EnvironmentVariableTarget]::User`) in
`src/ATAP.Utilities.PowerShell/Profiles/CurrentUserAllHostsV5Profile.ps1`:

| Variable                          | Value                                                                        |
| --------------------------------- | ---------------------------------------------------------------------------- |
| `VSCExtensionProjectName`         | `ATAP-AiAssist`                                                              |
| `VSCExtensionProjectRelativePath` | `src/ATAP.VSCExtension.ATAPAIAssist/ATAP-AiAssist`                           |
| `VSCExtensionProjectAbsolutePath` | `C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.VSCExtension.AI\ATAP-AiAssist` |

> Note: the original `VSCExtensionProjectAbsolutePath` points at the path while AIAssist
> still lives inside `ATAP.Utilities`. When AIAssist moves to its own repo, update this
> absolute path to the new repository root.

### Original set-site (for reference)

```powershell
[Environment]::SetEnvironmentVariable('VSCExtensionProjectName', 'ATAP-AiAssist', [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable('VSCExtensionProjectRelativePath', 'src/ATAP.VSCExtension.ATAPAIAssist/ATAP-AiAssist', [EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable('VSCExtensionProjectAbsolutePath', 'C:\Dropbox\whertzing\GitHub\ATAP.Utilities\src\ATAP.VSCExtension.AI\ATAP-AiAssist', [EnvironmentVariableTarget]::User)
```

## Consumers identified (Task 10.24 audit)

- `src/ATAP.Utilities.BuildTooling.PowerShell/public/Get-AllFilesChangedByCommit.ps1`
  previously defaulted its `-currentRepositoryPath` parameter to
  `$env:VSCExtensionProjectAbsolutePath`. Task 10.24 updated that default to a graceful
  fallback (current location) so the function still resolves without the env var. When
  AIAssist is re-homed, callers that relied on the env var should pass
  `-currentRepositoryPath` explicitly or set the variable in the AIAssist profile.

## Long-term intent (carried over from the original profile ToDo)

The original profile comment proposed replacing these static env vars with a VS Code
extension command that, on editor activation, matches the active document path against a
known set of project paths/names and sets the "current extension project" dynamically —
and/or moving these into `ConfigRootKeys` for the TypeScript/VSC-Extension process. Both
ideas belong with the AIAssist project when it moves.
