# PowerShell Modules — Pack and Publish

**Scope:** Sprint-0006/0007. How a built PowerShell module (`.psm1` + `.psd1`
under `_generated/psmodules/<Module>/packages/<Module>/`) becomes a `.nupkg`
and is published to the **Experimental** ProGet PowerShellGet feed; how that
same `.nupkg` is then **promoted** through Development → Integration → QA →
Production via `Promote-ProGetPackage`.

**Audience:** Developers running a local publish to the Experimental tier, anyone setting up
PowerShellGet repository registration, CI engineers wiring BuildMaster to
PowerShell publish steps.

**Status:** Authoritative for sprint-0006/0007.

> **Strategy update (sprint-0007 — Immutable Build).** The pack and publish
> happens **exactly once** at the Experimental tier. Movement of the same
> `.nupkg` into the Development, Integration, QA, and Production
> PowerShellGet feeds is by **promotion** (`Promote-ProGetPackage`) — not
> by re-pack/re-publish. This deprecates the pattern in §4 below where each
> tier was a separate `Publish-PSResource` call. Treat references to
> `Publish-PSModuleToProGetFeed -Tier Alpha` (or Beta, QA, Production) as legacy. The new
> single source of truth is `Publish-PSModuleToProGet` (drops the
> `-FeedTier` suffix; always targets Experimental) plus
> `Promote-ProGetPackage` for inter-feed movement. See
> [Immutable-Build-Strategy.md §5](Immutable-Build-Strategy.md#5-what-promotion-is-and-is-not).

**Not in this doc:**

- How the `.psm1`/`.psd1` get produced → see [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md).
- How the `ModuleVersion`/`Prerelease` are computed → see [PowerShell-Modules-Versioning.md](PowerShell-Modules-Versioning.md).
- ProGet feed topology, BuildMaster orchestration → see [BuildMaster-ProGet-CSharp-Package-Pipeline.md](BuildMaster-ProGet-CSharp-Package-Pipeline.md).
- Pester / coverage → see [PowerShell-Modules-Test-Process.md](PowerShell-Modules-Test-Process.md).

---

## 1. Two-step model: Pack, then Publish

A PowerShell module is shipped as a `.nupkg`. Under immutable build, pack
and push are two **separate** steps with the `.nupkg` as a named file on
disk between them:

```text
build (Build-PSModulePsm1 + Build-PSModuleManifest)
  → pack (New-PSModuleNupkg, produces .nupkg on disk)
    → push (Publish-PSModuleToProGet — uploads named .nupkg to PowershellGet-experimental)
```

Under immutable build, the `.nupkg` is the artifact. It must be a file on
disk with a stable SHA-256 before any push, so that the same bytes can be
promoted between feeds and so test evidence can be attached to a specific
`(ModuleId, Version, SHA-256)`. `New-PSModuleNupkg` produces the file;
`Publish-PSModuleToProGet` uploads it. Movement to higher tiers is by
`Promote-ProGetPackage` (see §12) — never by re-running the pack/publish
pair.

`New-PSModuleNupkg` and `Publish-PSModuleToProGet` are spec — see
[BuildMaster-Pipeline-Topology.md §4](BuildMaster-Pipeline-Topology.md#4-powershell-automation-surface)
for status.

---

## 2. Why `Publish-PSResource` and not `Publish-Module`

PowerShellGet has two generations:

| Generation      | Repo cmdlets                    | Publish cmdlet       | Status                                                                                                  |
| --------------- | ------------------------------- | -------------------- | ------------------------------------------------------------------------------------------------------- |
| v2 (legacy)     | `Register-PSRepository`         | `Publish-Module`     | Used by `Publish-PSPackage.ps1` (legacy Jenkins flow — being retired)                                   |
| v3 (PSResource) | `Register-PSResourceRepository` | `Publish-PSResource` | **What's wrapped** — `Publish-PSModuleToProGet` calls `Publish-PSResource -NupkgPath` against ProGet    |

PSResource v3 is faster, supports SemVer 2.0 prereleases more reliably, and
matches the cmdlet surface used by `dotnet`'s NuGet client. The legacy
v2 path remains in the codebase only because `Publish-PSPackage.ps1` has not
yet been deleted (see [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md) §12).

Under immutable build, the developer-facing entry-point is
`Publish-PSModuleToProGet -NupkgPath <file>`. It internally calls
`Publish-PSResource -NupkgPath` against the `PowershellGet-experimental`
feed. Developers should not call `Publish-PSResource` directly — doing so
obscures the artifact's file-on-disk identity and bypasses the
`(ModuleId, Version, SHA-256)` capture that the wrapper performs for the
BuildMaster release record.

---

## 3. The packed `.nupkg` layout

When `New-PSModuleNupkg -ModulePath <module-folder> -OutputPath <out>` runs, it
produces a `.nupkg` on disk with this layout:

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

The five PowerShellGet feeds form the tier-state mechanism. Under immutable
build, only the Experimental feed is a normal **publish** target — every
successful Experimental build pushes a `.nupkg` there exactly once. Movement
of that same `.nupkg` to the higher feeds is by **promotion**
(`Promote-ProGetPackage`, see §12), not by re-publishing.

| Tier         | Label name | ProGet feed name             | How a `.nupkg` arrives                                  |
| ------------ | ---------- | ---------------------------- | ------------------------------------------------------- |
| Experimental | `Sprint`   | `PowershellGet-experimental` | `Publish-PSModuleToProGet` (the only publish target)    |
| Development  | `Alpha`    | `PowershellGet-development`  | `Promote-ProGetPackage` from Experimental, after gates  |
| Integration  | `Beta`     | `PowershellGet-integration`  | `Promote-ProGetPackage` from Development, after gates   |
| QA           | `QA`       | `PowershellGet-qa`           | `Promote-ProGetPackage` from Integration, after gates   |
| Production   | *(none)*   | `PowershellGet-stable`       | `Promote-ProGetPackage` from QA, after manual approval  |

There is no `-Tier` or `-FeedTier` parameter on `Publish-PSModuleToProGet`:
the cmdlet always targets `PowershellGet-experimental`. The Label-to-tier
correspondence is metadata on the artifact (set at pack time by NBGV) and
must agree with the feed the artifact currently lives in — a deployment
script asserts label↔feed consistency before installing a module.

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
publish. `Publish-PSModuleToProGet` handles this idempotently for the
`PowershellGet-experimental` feed (the only feed it publishes to):

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

This is the call that `Publish-PSModuleToProGet` makes internally — once
the Experimental repo is registered and the API key is in hand:

```powershell
Publish-PSResource -NupkgPath $resolvedNupkg -Repository $feedName -ApiKey $apiKey
```

Note the wrapper passes `-NupkgPath` (a pre-built `.nupkg` path), not
`-Path` (a folder). The pack step (`New-PSModuleNupkg`) produces the
`.nupkg` separately so it can be test-uploaded with `-WhatIf`, hashed for
the BuildMaster release record, and promoted between feeds without ever
being rebuilt.

**Why `-NupkgPath` and not `-Path` (do not "simplify" this).**
`Publish-PSResource` accepts both forms, so it is tempting to collapse
the pack-then-publish steps by passing `-Path <folder>`. Do not. With
`-Path`, `Publish-PSResource` builds the `.nupkg` in a temp directory and
pushes it in a single step, so the exact bytes that land in ProGet are
never inspectable on disk. That breaks the immutable-build invariant:
the `(ModuleId, Version, SHA-256)` triple must be captured from a stable
file before push, and the same file must be the one promoted upward
through every tier. `-NupkgPath` is the only form that lets the pack
output be hashed, recorded, and re-used unchanged — `-Path` would
produce a fresh, unrecorded artifact on every call.

`Publish-PSResource` returns `$null` on success in many versions; the
wrapper wraps the result in a structured `PSCustomObject` for downstream
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
Publish-PSModuleToProGet -NupkgPath ./out/Foo.0.1.0-Sprint042.nupkg -WhatIf
# Returns Published = $false, ResponseSummary = "WhatIf: planned publish ..."
```

This is the recommended way to verify a CI step's resolved feed before
provisioning the API key.

---

## 10. End-to-end developer publish

Full sequence to build, pack, and publish one module to the Experimental
PowerShellGet feed. Pack and push are two distinct steps with the
`.nupkg` as a named file between them:

```powershell
# 1. Build (see Build-Process doc §7) — produces .psm1 + .psd1 in
#    _generated/psmodules/<Module>/packages/<Module>/
$meta = Resolve-PSModuleMetadata -StartPath ./src/ATAP.Utilities.FileIO.PowerShell
$v    = Get-PSModuleVersionFromNBGV -ModuleRoot $meta.ModuleRoot
# ...Build-PSModulePsm1 + Build-PSModuleManifest...

# 2. Pack: produce a .nupkg on disk
$nupkg = New-PSModuleNupkg -ModulePath "$($meta.OutputRoot)/packages/$($meta.ModuleName)" `
                           -OutputPath "$($meta.OutputRoot)/packages-nupkg"

# 3. Push: upload the .nupkg to the Experimental feed
Publish-PSModuleToProGet -NupkgPath $nupkg.FullName

# 4. Higher tiers: promote via Promote-ProGetPackage (see §12)
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

As of sprint-0006 (Area 2.5-3), this script also iterates and publishes
PowerShell modules. Under the sprint-0007 immutable-build update, each
iteration calls `New-PSModuleNupkg` to produce a `.nupkg` and then
`Publish-PSModuleToProGet` to push it to `PowershellGet-experimental`. The
PowerShell-module publish flow is documented in §10. (Older revisions of
this script called the legacy `Publish-PSModuleToProGetFeed -Tier <X>`
cmdlet — that cmdlet is deprecated in favor of the pack/push pair.)

---

## 12. Promotion across tiers (Sprint-7 immutable-build flow)

Under the immutable-build strategy, **every** tier above Experimental is
reached by promotion. The `.nupkg` is published to
`PowershellGet-experimental` exactly once and then promoted upward as gates
pass. The full flow:

1. Developer (or CI) publishes the module to `PowershellGet-experimental`
   via `Publish-PSModuleToProGet`. This is the **only** publish call.
2. BuildMaster's PowerShell-Module-Pipeline runs Pester / PSScriptAnalyzer
   / coverage gates against the module from `PowershellGet-experimental`.
   On pass, `Promote-ProGetPackage` copies the same `.nupkg` to
   `PowershellGet-development`.
3. Each subsequent tier gate restores the module from its current feed,
   runs tier-appropriate tests, and on pass promotes to the next feed.
4. Production-tier promotion is gated on a manual approval from the
   release manager — see [BuildMaster-Pipeline-Topology.md §3](BuildMaster-Pipeline-Topology.md#3-buildmaster-application-catalog).

ProGet's connectors / hermetic-feed configurations remain in place for
**restore visibility** (so a developer pulling from `PowershellGet-qa`
can resolve indirect ProGet packages from earlier tiers). They are not
the promotion mechanism — `Promote-ProGetPackage` is.

---

## 13. Common failures and remedies

| Error | Cause | Fix |
| ----- | ----- | --- |
| `feed URI for tier X is not configured` (raised inside `Promote-ProGetPackage`) | Neither `$global:settings` nor the env var holds the URI for the **target** feed of a promotion. `Publish-PSModuleToProGet` itself only needs the Experimental URI. | `[Environment]::SetEnvironmentVariable('PROGET_POWERSHELLGET_FEED_URI_DEVELOPMENT','http://localhost:50000/nuget/PowershellGet-development/','User')` (substitute the target tier) |
| `Unable to resolve ProGet API key for tier X` | Bitwarden secret missing AND env var unset | Add Bitwarden item `ProGet_PowerShellGet_<Tier>_ApiKey` or set `PROGET_POWERSHELLGET_APIKEY_<TIER>` |
| `Publish-PSResource: A NuGet feed already contains this package` | Same `Module.Version` already published | Bump the height (commit something) and rebuild; ProGet rejects re-uploads |
| `Publish-PSResource: ResourceUnauthorized` | API key invalid or wrong tier | Verify the key in ProGet UI (Admin → API Keys) matches the tier |
| `NupkgPath does not exist or is not a file` | Build did not produce the `.nupkg` (path mismatch) | Confirm the pack step ran; check `$meta.OutputRoot/packages-nupkg/` |
| `NupkgPath must have a .nupkg extension` | A folder path was passed instead of a file | Pass the resolved `.nupkg`, not the module folder |
| `Repository <name> already registered with different URI` | A previous run registered a stale URI | The cmdlet will `Set-PSResourceRepository` to fix; if it loops, manually `Unregister-PSResourceRepository` and retry |

---

## 14. Known drift and gaps (sprint-0006/0007)

1. **`New-PSModuleNupkg` and `Publish-PSModuleToProGet` are spec.** Both
   cmdlets are referenced by this doc and by the BuildMaster pipelines but
   have not yet been implemented in `ATAP.Utilities.BuildTooling.PowerShell`.
   Their stub status is tracked in
   [BuildMaster-Pipeline-Topology.md §4](BuildMaster-Pipeline-Topology.md#4-powershell-automation-surface).
   The legacy `Publish-PSModuleToProGetFeed -Tier <X>` cmdlet exists in the
   module today but is **deprecated** under the immutable-build strategy
   (it conflated pack and push and assumed publish-per-tier). Replace any
   call to `Publish-PSModuleToProGetFeed -Tier <X>` with the
   pack/push/promote sequence in §10.

2. **No `Get-TierFromNBGVLabel` helper** — task T-12 is unmerged. Under
   immutable build this matters less (only the Experimental publish needs
   to know it is Experimental, and `Publish-PSModuleToProGet` hard-codes
   that target), but it is still needed by `Promote-ProGetPackage` callers
   that derive the source feed from the artifact's prerelease label.

3. ~~**No `Get-ATAPIACConstant` integration** — task T-30.~~ **Resolved (sprint-0006
   §7.1-3):** the publish helper now looks up feed names and URIs via
   `Get-ATAPIACConstant` (`FeedConstants.psd1`). Env-var fallback retained
   for agent shells.

4. ~~**`Publish-ATAPUtilities.ps1` does not publish PowerShell modules.**~~
   **Resolved (sprint-0006 §2.5-3):** `Publish-ATAPUtilities.ps1` now includes a
   PowerShell-modules section. Sprint-0007 update: that section calls
   `New-PSModuleNupkg` followed by `Publish-PSModuleToProGet` for each
   module. See §11 above.

5. **Repository name collisions are not detected.** If two tiers point at
   the same feed URI by accident, the second registration silently wins.

6. ~~**No retention policy enforcement.**~~ **Resolved (sprint-0006 §5.1-3):**
   `RetentionPolicy` entries are now declared in `ProGetFeedCollection`
   (`HostSettings.IAC.Fragment.PackageRepositories.ProGetFeeds.ps1`) and applied
   by `New-ProGetFeedSet`: experimental = 7 days, development = 30 days,
   integration/qa = indefinite (hermetic), stable = indefinite.

7. **The legacy `Publish-PSPackage.ps1` is still exported** — see
   [PowerShell-Modules-Build-Process.md](PowerShell-Modules-Build-Process.md) §12.3.
   It will silently fail in any environment that does not have the
   ancient `\\utat022\FS\...` UNC share mounted.

---

## 15. Quick reference

Pack a module folder into a `.nupkg` on disk:

```powershell
$nupkg = New-PSModuleNupkg `
    -ModulePath ./_generated/psmodules/ATAP.Utilities.FileIO.PowerShell/packages/ATAP.Utilities.FileIO.PowerShell `
    -OutputPath ./_generated/psmodules/ATAP.Utilities.FileIO.PowerShell/packages-nupkg
```

Publish that `.nupkg` to the Experimental PowerShellGet feed:

```powershell
Publish-PSModuleToProGet -NupkgPath $nupkg.FullName
```

Dry-run check (no upload):

```powershell
Publish-PSModuleToProGet -NupkgPath ./out/Foo.0.1.0-Sprint042.nupkg -WhatIf
```

Promote an Experimental `.nupkg` to the Development feed:

```powershell
Promote-ProGetPackage `
    -Name     'ATAP.Utilities.FileIO.PowerShell' `
    -Version  '0.1.0-Alpha042' `
    -FromFeed 'PowershellGet-experimental' `
    -ToFeed   'PowershellGet-development' `
    -Reason   'DEV-PASS for build #4272'
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
