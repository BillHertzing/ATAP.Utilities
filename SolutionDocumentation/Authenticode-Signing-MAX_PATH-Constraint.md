# Authenticode Signing and the MAX_PATH Constraint

**Status:** Open defect. Blocks signing for long-named modules built from a sprint
worktree. Discovered 2026-08-03 while releasing
`ATAP.Utilities.BuildTooling.PlanningSession.PowerShell` 0.1.4.

`Set-AuthenticodeSignature` fails on any file whose full path exceeds **260 characters**
(`MAX_PATH`), even when the file demonstrably exists and even when the machine has long
paths enabled. The failure is reported as a misleading generic error:

```text
Status  : UnknownError
Message : The system cannot find the path specified.
```

The message says "cannot find the path", but the file is there. The real cause is path
length.

## Why `LongPathsEnabled` does not save you

This machine has the registry opt-in set:

```powershell
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled).LongPathsEnabled
# 1
```

That setting only affects processes whose application manifest declares
`longPathAware`. The Authenticode signing path runs through native Windows crypto APIs
that are not long-path aware, so the limit still applies. .NET file APIs in the same
session *do* handle the long path, which is what makes the failure so confusing:

```powershell
[System.IO.File]::Exists($path)   # True  - .NET is fine
Set-AuthenticodeSignature -FilePath $path -Certificate $cert   # UnknownError
```

The `\\?\` extended-length prefix is **not** a workaround here: `Set-AuthenticodeSignature`
is a PowerShell-provider cmdlet and does not accept the prefixed form (it returns an empty
status rather than signing).

## Reproduction

Independent of any ATAP tooling:

```powershell
$pad  = 'x' * 80
$deep = Join-Path $env:TEMP "$pad\$pad"
New-Item -ItemType Directory -Path $deep -Force | Out-Null
$long = Join-Path $deep 'probe.ps1'
'Get-Date' | Set-Content $long -Encoding utf8
$long.Length      # 336

$cert = Get-ChildItem Cert:\LocalMachine\My |
  Where-Object Thumbprint -eq '<code-signing-thumbprint>'

Set-AuthenticodeSignature -FilePath $long -Certificate $cert |
  Select-Object Status, StatusMessage
# Status=UnknownError  StatusMessage=The system cannot find the path specified.
```

Signing the same content at a short path with the same certificate succeeds, with and
without a timestamp server. The certificate, its private key ACL, and the service account
are **not** the problem.

## How the build exceeds 260 characters

The failing path was **290 characters**:

```text
C:\Dropbox\whertzing\GitHub\ATAP.Utilities-wt-132-Sprint-0014-work-items   (72)
  \_generated\buildmaster\21241\psmodules                                  (+39 = 111)
  \ATAP.Utilities.BuildTooling.PlanningSession.PowerShell                  (+55 = 166)
  \packages                                                                (+9  = 175)
  \ATAP.Utilities.BuildTooling.PlanningSession.PowerShell                  (+55 = 230)
  \ATAP.Utilities.BuildTooling.PlanningSession.PowerShell.psd1             (+60 = 290)
```

Three multipliers stack:

1. **A long worktree root.** Sprint worktrees add `-wt-<issue>-Sprint-NNNN-work-items`,
   costing ~30 characters over the stable root. A build that fits from the stable worktree
   can fail from the sprint worktree.
2. **The module name appears three times** in the staging layout —
   `psmodules\<name>\packages\<name>\<name>.psd1`. At 55 characters per occurrence that is
   170 characters of the budget.
3. **Deep build-scoped staging** under `_generated\buildmaster\<BuildMasterBuildId>\`.

Because the module name is counted three times, the constraint bites hardest on exactly
the modules with the most descriptive names. Any ATAP module whose name is roughly 50
characters or longer is at risk from a sprint worktree.

### Quick check before releasing

```powershell
$repoRoot   = '<sprint worktree root>'
$moduleName = '<module name>'
$probe = Join-Path $repoRoot "_generated\buildmaster\99999\psmodules\$moduleName\packages\$moduleName\$moduleName.psd1"
$probe.Length   # >260 means signing will fail
```

## Candidate fixes

Not yet implemented — the choice is a design decision for the build-tooling owner.

1. **Shorten the staging layout (preferred).** The module name does not need to appear
   three times. Collapsing `psmodules\<name>\packages\<name>\` to a single level reclaims
   ~64 characters and fixes every current module without touching signing code. Changes
   `Invoke-PowerShellModuleBuildMasterStage.ps1`.
2. **Sign through a short temporary path.** In `Set-PSModuleFileSignature.ps1`, copy each
   file to a short scratch path (for example `C:\s\<guid>\<file>`), sign it there, and copy
   the signed bytes back. Robust against any future path growth, at the cost of extra I/O
   and a more complex worker.
3. **Use a substituted drive for the build root.** `subst B: <worktreeRoot>` shortens the
   prefix to three characters. Effective but environmental — it must hold for the
   BuildMaster service account too, which makes it fragile as the primary fix.

Whichever is chosen, `Set-PSModuleFileSignature.ps1` should also **detect the condition and
say so**, rather than surfacing the raw `UnknownError`:

```powershell
if ($file.FullName.Length -gt 260) {
  throw "Cannot Authenticode-sign '$($file.FullName)': the path is " +
        "$($file.FullName.Length) characters, over the 260-character MAX_PATH limit that " +
        "the signing API enforces regardless of LongPathsEnabled. See " +
        "SolutionDocumentation/Authenticode-Signing-MAX_PATH-Constraint.md."
}
```

That single guard converts a half-hour investigation into a one-line diagnosis.

## Related: bootstrapping the signature gate

The signing work also introduced a **circular dependency** that will recur on any machine
whose installed `ATAP.Utilities.BuildTooling.ProGet.PowerShell` predates the gate:

- `Promote-ProGetPackage` calls `Assert-ProGetPowerShellPackageSignature`, which calls
  `Test-PSModulePackageSignature`.
- Both functions ship **in that module**. If the installed copy predates them, every
  promotion fails with `The term 'Test-PSModulePackageSignature' is not recognized`.
- The module cannot promote itself past Experimental, because promoting requires the very
  function the promotion is trying to publish.

Break the cycle by installing the package from the **Experimental** feed (where it lands
before the gate runs), then promoting normally, then reinstalling the Production artifact:

```powershell
# 1. Verify the experimental package is signed and contains the function before installing.
# 2. Install it AllUsers through the elevation broker, Repository = powershellget-experimental.
# 3. Re-run the pipeline; promotion now resolves the function and proceeds to stable.
# 4. Reinstall AllUsers from powershellget-stable so the installed artifact is Production.
```

Step 4 is not optional: the experimental and stable `.nupkg` files have **different
SHA-256 hashes** (ProGet regenerates the package on promotion), so promotion is *not* a
byte-for-byte copy and the experimental bytes are not the Production bytes.

## Symptom-to-cause table

| Symptom | Likely cause |
| --- | --- |
| `UnknownError` / "cannot find the path specified", file exists | Path over 260 characters |
| `UnknownError`, path is short | Timestamp server unreachable; retry without `-TimestampServer` to isolate |
| "Cannot find certificate" / key errors | Service account lacks read on the private key in `%ProgramData%\Microsoft\Crypto\RSA\MachineKeys` |
| Signing works interactively, fails under BuildMaster | Compare the two paths first — the service builds under `_generated\buildmaster\<id>\`, which is deeper |

## Related documentation

- [BuildMaster-Plan-Raft-Sync-Requirement.md](BuildMaster-Plan-Raft-Sync-Requirement.md)
- [Security-PowerShell-Module-Architecture.md](Security-PowerShell-Module-Architecture.md)
- [RRSBS-ADR-185-PKIArtifact-Metadata-Only-Contract.md](RRSBS-ADR-185-PKIArtifact-Metadata-Only-Contract.md)
- [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md)
