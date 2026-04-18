# PowerShell Modules — Pack and Publish

**Scope:** Sprint-0006. How a built PowerShell module (`.psm1` + `.psd1` under
`_generated/psmodules/<Module>/packages/<Module>/`) becomes a `.nupkg` and is
published to the correct ProGet PowerShellGet feed for its tier.

**Audience:** Developers running a local publish to T1, anyone setting up
PowerShellGet repository registration, CI engineers wiring BuildMaster to
PowerShell publish steps.

**Status:** Authoritative for sprint-0006.

**Not in this doc:**
- How the `.psm1`/`.psd1` get produced → see [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md).
- How the `ModuleVersion`/`Prerelease` are computed → see [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md).
- ProGet feed topology, BuildMaster orchestration → see [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md).
- Pester / coverage → see [PowerShell-Modules-Test-Process.md](PowerShell-Modules-Test-Process.md).

---

## 1. Two-step model: Pack, then Publish

A PowerShell module is shipped as a `.nupkg`. The lifecycle is:

```text
build (Build-PSModulePsm1 + Build-PSModuleManifest)
  → pack (Publish-PSResource implicitly, or Compress-Archive for legacy)
    → push (Publish-PSResource + Repository → ProGet PowerShellGet feed)
```

In modern PowerShellGet (PSResource v3+), pack and push are bundled in one
`Publish-PSResource` invocation against an already-registered repository.
We do not run a separate `nuget pack` step.

The cmdlet that wraps all of this is
`src/ATAP.Utilities.BuildTooling.PowerShell/public/Publish-PSModuleToProGetFeed.ps1`.

---

## 2. Why `Publish-PSResource` and not `Publish-Module`

PowerShellGet has two generations:

| Generation | Repo cmdlets                  | Publish cmdlet     | Status                        |
| ---------- | ----------------------------- | ------------------ | ----------------------------- |
| v2 (legacy) | `Register-PSRepository`       | `Publish-Module`   | Used by `Publish-PSPackage.ps1` (legacy Jenkins flow — being retired) |
| v3 (PSResource) | `Register-PSResourceRepository` | `Publish-PSResource` | **Current** — used by `Publish-PSModuleToProGetFeed` |

PSResource v3 is faster, supports SemVer 2.0 prereleases more reliably, and
matches the cmdlet surface used by `dotnet`'s NuGet client. The legacy
v2 path remains in the codebase only because `Publish-PSPackage.ps1` has not
yet been deleted (see [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md) §12).

---

## 3. The packed `.nupkg` layout

When `Publish-PSResource -Path <module-folder>` runs, it produces an internal
`.nupkg` with this layout:

```text
<Module>.<Major>.<Minor>.<Patch>[-<Prerelease>].nupkg
├── _rels/
├── package/
├── [Content_Types].xml
├── <Module>.nuspec                    # generated from .psd1
└── <Module>/                          # the module folder, copied verbatim
    ├── <Module>.psm1
    └── <Module>.psd1
```

Notes:
- The package version is derived from the `.psd1` `ModuleVersion` +
  `Prerelease` (see [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md)).
- `.nuspec` is auto-generated; we do not author it.
- The published file name uses dot-separated version (`Foo.0.1.0-Sprint042.nupkg`),
  not hyphen-separated.

---

## 4. Tier-to-feed mapping

The publish cmdlet maps the tier to a PowerShellGet feed name. The mapping is
inlined in `Publish-PSModuleToProGetFeed.ps1` until task **T-12**
(`Get-TierFromNBGVLabel`) is merged:

| Tier name    | ProGet feed name                | Purpose                              |
| ------------ | ------------------------------- | ------------------------------------ |
| `Sprint`     | `PowershellGet-experimental`    | T1 — every successful build          |
| `Alpha`      | `PowershellGet-development`     | T2 — passes unit tests               |
| `Beta`       | `PowershellGet-integration`     | T3 — passes integration tests        |
| `QA`         | `PowershellGet-qa`              | T4 — release candidate               |
| `Production` | `PowershellGet-stable`          | T5 — released                        |

The `-Tier` parameter is `[ValidateSet]`-constrained to these five values.
Any other value throws before any network call.

---

## 5. Feed URI resolution

The feed name → URI mapping is resolved in this order (first match wins):

1. **`$global:settings`** via `$global:configRootKeys["PowerShellGetFeed_$Tier"]`.
   This is the canonical source once the global settings are loaded by the
   user's profile.
2. **User-scope environment variable** `PROGET_POWERSHELLGET_FEED_URI_<TIER>`
   (e.g. `PROGET_POWERSHELLGET_FEED_URI_SPRINT`). Read via
   `[Environment]::GetEnvironmentVariable($name, 'User')` per rule R-10.
3. If neither resolves → throw with hint to set the env var or wait for
   T-30 `Get-ATAPIACConstant`.

The User-scope env-var fallback is what lets a fresh agent shell publish
without depending on the user's interactive PowerShell profile.

Typical URI shape: `http://localhost:50000/nuget/PowershellGet-experimental/`.
See [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md) §3.

---

## 6. API-key resolution

ProGet requires an API key for write operations. Resolution order:

1. **Bitwarden** — call `Get-BitWardenSecret -SecretName "ProGet_PowerShellGet_${Tier}_ApiKey"`.
   Wrapped in `try/catch`; failure falls through to env var.
2. **User-scope environment variable** `PROGET_POWERSHELLGET_APIKEY_<TIER>`
   (e.g. `PROGET_POWERSHELLGET_APIKEY_SPRINT`).
3. If neither resolves → throw with both lookup names included in the
   message so the operator can fix one or the other.

The resolved key is **never logged** — every PSFramework log entry redacts
the value.

---

## 7. Repository registration

PowerShellGet v3 requires a registered `PSResourceRepository` per feed before
publish. `Publish-PSModuleToProGetFeed` handles this idempotently:

```powershell
$existing = Get-PSResourceRepository -Name $feedName -ErrorAction SilentlyContinue
if ($null -eq $existing) {
    Register-PSResourceRepository -Name $feedName -Uri $feedUri -Trusted
} elseif ($existing.Uri -ne $feedUri) {
    Set-PSResourceRepository -Name $feedName -Uri $feedUri -Trusted
}
# else: already registered with the right URI — no-op
```

`-Trusted` suppresses interactive consent prompts. This is safe for our
internal feeds because we own them; it must **not** be applied to nuget.org
or PSGallery.

---

## 8. The publish call

Once the repo is registered and the API key is in hand:

```powershell
Publish-PSResource -NupkgPath $resolvedNupkg -Repository $feedName -ApiKey $apiKey
```

Note we pass `-NupkgPath` (a pre-built `.nupkg` path), not `-Path` (a
folder). Our build path produces the `.nupkg` separately so it can be
test-uploaded with `-WhatIf` before commit.

`Publish-PSResource` returns `$null` on success in many versions; the
cmdlet wraps the result in a structured `PSCustomObject` for downstream
consumers:

```powershell
[PSCustomObject]@{
    NupkgPath       = $resolvedNupkg
    FeedName        = $feedName
    FeedUri         = $feedUri
    Published       = $true
    ResponseSummary = '...stringified result or completion note...'
}
```

---

## 9. WhatIf / dry-run mode

`-WhatIf` short-circuits before `Publish-PSResource`. The returned object
still carries the resolved feed name + URI, so callers can verify the
publish *plan* without contacting ProGet:

```powershell
Publish-PSModuleToProGetFeed -NupkgPath ./out/Foo.0.1.0-Sprint042.nupkg `
                              -Tier Sprint -WhatIf
# Returns Published = $false, ResponseSummary = "WhatIf: planned publish ..."
```

This is the recommended way to verify a CI step's resolved feed before
provisioning the API key.

---

## 10. End-to-end developer publish

Full sequence to publish one module to T1:

```powershell
# 1. Build (see Build-Process doc §7)
$meta = Resolve-PSModuleMetadata -StartPath ./src/ATAP.Utilities.FileIO.PowerShell
$v    = Get-PSModuleVersionFromNBGV -ModuleRoot $meta.ModuleRoot
$pkgFolder = "$($meta.OutputRoot)/packages/$($meta.ModuleName)"
# ...Build-PSModulePsm1 + Build-PSModuleManifest...

# 2. Pack into .nupkg
$nupkgFolder = "$($meta.OutputRoot)/packages-nupkg"
New-Item -ItemType Directory -Path $nupkgFolder -Force | Out-Null
Publish-PSResource -Path $pkgFolder -Repository (Get-PSResourceRepository -Name PowershellGet-experimental).Uri `
                   -SkipDependenciesCheck -OutputDirectory $nupkgFolder
# (or use the legacy nuget pack path if PSResource produces a .nupkg in-place)

$nupkg = Get-ChildItem -Path $nupkgFolder -Filter "*.nupkg" | Select-Object -First 1

# 3. Publish to T1 (Sprint)
Publish-PSModuleToProGetFeed -NupkgPath $nupkg.FullName -Tier Sprint
```

In practice steps 1–3 are wrapped by the per-module `Publish-ATAPUtilities.ps1`
helper at the repo root.

---

## 11. The repo-root developer helper

`Publish-ATAPUtilities.ps1` (at the ATAP.Utilities repo root) exists for the
developer's local "publish everything I just changed" loop. Behavior:

1. Validates `PROGET_ADMIN_API_KEY` is set (User scope).
2. Resolves the solution root via `git rev-parse --show-toplevel`.
3. Iterates a hand-maintained `$libraries` array in dependency order
   (currently `ATAP.Utilities.ETW`, `ATAP.Utilities.Configuration.Extensions`).
4. For each library, runs `dotnet build` (with `ATAPBuildToolingConfiguration=Debug`
   when verbose) followed by the publish call.

This script is **C#-centric** (despite living in the same repo). The
PowerShell-module equivalent is the per-module flow in §10. A unified
`Publish-AllPSModules.ps1` orchestrator is on the sprint-0007 backlog.

---

## 12. Hermetic feeds at T3 / T4

ProGet feeds at T3 (integration) and T4 (qa) are configured as **hermetic**
— they cache packages from upstream feeds rather than requiring a separate
publish. Promotion from T2 → T3 happens via ProGet's connector + retention
rules, not via a re-publish.

Implication: `Publish-PSModuleToProGetFeed -Tier Beta` is rarely the right
call from a developer's machine. The intended flow is:

1. Developer publishes `Sprint` → T1.
2. CI promotes to `Alpha` → T2 after unit tests.
3. ProGet's hermetic connector promotes to T3 / T4 automatically based on
   integration / QA test gates.
4. Manual `Publish-PSResource -Tier Production` is the only "explicit"
   re-publish, and only for the final release.

---

## 13. Common failures and remedies

| Error                                                                 | Cause                                                          | Fix                                                                  |
| --------------------------------------------------------------------- | -------------------------------------------------------------- | -------------------------------------------------------------------- |
| `feed URI for tier X is not configured`                               | Neither `$global:settings` nor the env var holds the URI       | `[Environment]::SetEnvironmentVariable('PROGET_POWERSHELLGET_FEED_URI_SPRINT','http://localhost:50000/nuget/PowershellGet-experimental/','User')` |
| `Unable to resolve ProGet API key for tier X`                         | Bitwarden secret missing AND env var unset                     | Add Bitwarden item `ProGet_PowerShellGet_<Tier>_ApiKey` or set `PROGET_POWERSHELLGET_APIKEY_<TIER>` |
| `Publish-PSResource: A NuGet feed already contains this package`     | Same `Module.Version` already published                        | Bump the height (commit something) and rebuild; ProGet rejects re-uploads |
| `Publish-PSResource: ResourceUnauthorized`                            | API key invalid or wrong tier                                  | Verify the key in ProGet UI (Admin → API Keys) matches the tier      |
| `NupkgPath does not exist or is not a file`                           | Build did not produce the `.nupkg` (path mismatch)             | Confirm the pack step ran; check `$meta.OutputRoot/packages-nupkg/` |
| `NupkgPath must have a .nupkg extension`                              | A folder path was passed instead of a file                     | Pass the resolved `.nupkg`, not the module folder                    |
| `Repository <name> already registered with different URI`             | A previous run registered a stale URI                          | The cmdlet will `Set-PSResourceRepository` to fix; if it loops, manually `Unregister-PSResourceRepository` and retry |

---

## 14. Known drift and gaps (sprint-0006)

1. **No `Get-TierFromNBGVLabel` helper** — task T-12 is unmerged. Until
   then, the tier is passed explicitly as a `-Tier` parameter and the
   developer must keep it consistent with the module's `version.json`
   prerelease label.

2. **No `Get-ATAPIACConstant` integration** — task T-30. Feed URIs are
   resolved via env vars; no central registry yet.

3. **`Publish-ATAPUtilities.ps1` does not publish PowerShell modules** —
   it only handles C# packages. The two parallel publish helpers should be
   unified.

4. **Repository name collisions are not detected.** If two tiers point at
   the same feed URI by accident, the second registration silently wins.

5. **No retention policy enforcement** — old `Sprint` builds accumulate
   unbounded in the T1 feed. ProGet has retention rules but they are not
   declared in code.

6. **The legacy `Publish-PSPackage.ps1` is still exported** — see
   [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md) §12.3.
   It will silently fail in any environment that does not have the
   ancient `\\utat022\FS\...` UNC share mounted.

---

## 15. Quick reference

Publish one module to Sprint (T1):

```powershell
Publish-PSModuleToProGetFeed `
  -NupkgPath ./out/ATAP.Utilities.FileIO.PowerShell.0.1.0-Sprint042.nupkg `
  -Tier Sprint
```

Dry-run check (no upload):

```powershell
Publish-PSModuleToProGetFeed -NupkgPath ./out/Foo.0.1.0-Sprint042.nupkg -Tier Sprint -WhatIf
```

List currently registered repositories:

```powershell
Get-PSResourceRepository | Select-Object Name, Uri, Trusted
```

Drop a stale registration:

```powershell
Unregister-PSResourceRepository -Name PowershellGet-experimental
```

---

## Related Documents

- [Production-and-Tooling-Overview.md](Production-and-Tooling-Overview.md) — index.
- [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md) — generates the inputs to pack.
- [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md) — produces the `Prerelease` that selects the tier.
- [PowerShell-Modules-Test-Process.md](PowerShell-Modules-Test-Process.md) — gating tests between tiers.
- [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md) — feed topology and CI orchestration.
