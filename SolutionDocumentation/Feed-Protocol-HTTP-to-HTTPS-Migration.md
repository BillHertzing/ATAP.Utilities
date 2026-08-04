# Feed Protocol Migration: HTTP to HTTPS

**Status:** Client registrations migrated 2026-08-03. Source-code fallback defaults still
pending (see [Remaining work](#remaining-work)).

This runbook describes how ProGet and BuildMaster moved from `http://` to `https://`, what
had to change on each consuming surface, and how to verify and roll back. It is the
companion to [ProGet-Install-Runbook.md](ProGet-Install-Runbook.md) and
[BuildMaster-Install-Runbook.md](BuildMaster-Install-Runbook.md).

## Why this migration happened

A PKI change issued an SSL certificate for the `utat022` host. ProGet (port `50000`) and
BuildMaster (port `50017`) were reconfigured to serve HTTPS. Both services now **refuse
plain HTTP** — an `http://` request does not redirect, it fails with
`The response ended prematurely (ResponseEnded)`.

This is a hard cutover, not a dual-listen period. Every client registration that still
names `http://` breaks at the moment of the server change.

## The two changes, not one

The migration changes **both** the scheme and, for some surfaces, the host name.

| Aspect | Before | After |
| --- | --- | --- |
| Scheme | `http` | `https` |
| Host (PowerShell feeds) | `utat022` | `utat022` (unchanged) |
| Host (dotnet/NuGet feeds) | `localhost` | `utat022` (**changed**) |
| ProGet port | `50000` | `50000` (unchanged) |
| BuildMaster port | `50017` | `50017` (unchanged) |

The host change is not cosmetic. The certificate's Subject Alternative Name contains
**only** `DNS Name=utat022`. A request to `https://localhost:50000` therefore fails
certificate validation with a name mismatch even though the same service answers on that
address. Any registration that survives as `localhost` over HTTPS is broken.

Verify the SAN before assuming a host name is usable:

```powershell
$callback = { param($sender, $cert, $chain, $errors) $true }
$tcp = [System.Net.Sockets.TcpClient]::new('utat022', 50000)
$ssl = [System.Net.Security.SslStream]::new($tcp.GetStream(), $false, $callback)
$ssl.AuthenticateAsClient('utat022')
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$ssl.RemoteCertificate
$cert.Subject
($cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' }).Format($false)
$ssl.Dispose(); $tcp.Dispose()
```

## Source of truth: host settings, not hand-typed URLs

The canonical feed URIs live in host settings, reachable through `Get-HostSettings` and
`$global:configRootKeys` (see [ConfigRootKeys-and-HostSettings.md](ConfigRootKeys-and-HostSettings.md)).
These were migrated to HTTPS ahead of the client registrations, so settings are the
correct source to drive re-registration from.

```powershell
Set-GlobalConfigRootKeys | Out-Null
$settings = Get-HostSettings -hostName $env:COMPUTERNAME

$settings['ProGetBaseUrl']                     # https://utat022:50000/
$settings['BuildMasterBaseUrl']                # https://utat022:50017/
$settings['ProGetFeedPowerShellStableUri']     # https://utat022:50000/nuget/powershellget-stable/
$settings['ProGetFeedCollection']              # hashtable of all 15 declared feeds
```

**Never hand-type a feed URL into a registration command.** Read it from settings so the
registration cannot drift from the declared configuration.

> **Profile caveat in agent shells.** `$global:settings` and `$global:configRootKeys` are
> populated by the PowerShell profile. Agent-spawned and `-NoProfile` shells do not have
> them. Bootstrap explicitly with `Set-GlobalConfigRootKeys` followed by
> `Get-HostSettings -hostName $env:COMPUTERNAME`, in that order — `Get-HostSettings`
> throws if the config root keys are not already populated.

## The four client surfaces

A complete migration touches four independent registration stores. Migrating only the
first is the most common failure, because `Find-Module` then works while `Install-PSResource`
and `dotnet restore` still fail.

| # | Surface | Enumerate with | Feeds |
| --- | --- | --- | --- |
| 1 | PowerShellGet v2 repositories | `Get-PSRepository` | 5 `powershellget-*` |
| 2 | PSResourceGet repositories | `Get-PSResourceRepository` | 5 `powershellget-*` |
| 3 | dotnet/NuGet sources | `dotnet nuget list source` | 5 `nuget-*`, 5 `releasebundle-*`, 5 `database-*` |
| 4 | Repo `NuGet.Config` files | `Get-ChildItem -Filter nuget.config -Recurse` | per-repo |

Surfaces 1 and 2 are per Windows user profile. Surface 3 is per user profile
(`%APPDATA%\NuGet\NuGet.Config`) unless overridden by a repo-level file. Surface 4 is
checked into git and shared by everyone.

### The feed inventory

The ProGet server hosts **20** feeds in four families of five tiers:

| Family | Type | Path form | Tiers |
| --- | --- | --- | --- |
| `powershellget-*` | powershell | `/nuget/<feed>/` | experimental, development, integration, qa, stable |
| `nuget-*` | nuget | `/nuget/<feed>/v3/index.json` | experimental, development, integration, qa, stable |
| `database-*` | nuget | `/nuget/<feed>/v3/index.json` | experimental, development, integration, qa, stable |
| `releasebundle-*` | universal | `/upack/<feed>/` | experimental, development, integration, qa, **production** |

Note the tier-name asymmetry: the release-bundle family's top tier is `production`, while
the other three families use `stable`. `Resolve-DatabasePackageFeed` maps the Production
tier to `database-stable`, not `database-production`.

Enumerate the server's actual feeds rather than trusting a list:

```powershell
Set-GlobalConfigRootKeys | Out-Null
$settings = Get-HostSettings -hostName $env:COMPUTERNAME
$apiKey = Get-SecretATAP -SecretName $settings['ProGetAdminApiKeySecretName']

Invoke-RestMethod -Uri 'https://utat022:50000/api/management/feeds/list' `
  -Headers @{ 'X-ApiKey' = $apiKey } |
  Select-Object name, feedType, active |
  Sort-Object feedType, name
```

> **Settings gap.** `ProGetFeedCollection` declares 15 feeds; the server hosts 20. The five
> `database-*` feeds have no `ProGetFeed*` settings entries. They are consumed by name
> server-side inside BuildMaster plans (`Resolve-DatabasePackageFeed` returns a feed *name*,
> not a URI), which is why the omission went unnoticed. Adding them to host settings is
> tracked under [Remaining work](#remaining-work).

## Migration procedure

Run each step from a normal (non-elevated) PowerShell 7 session for the user who consumes
the feeds. Capture before-state first — every step is reversible from it.

### Step 0: Capture before-state

```powershell
$evidence = Join-Path $repoRoot '_generated\feed-https-migration'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Get-PSRepository | Select-Object Name, SourceLocation, PublishLocation, InstallationPolicy |
  ConvertTo-Json -Depth 4 |
  Set-Content (Join-Path $evidence "before-psrepository-$stamp.json") -Encoding utf8

Get-PSResourceRepository | Select-Object Name, Uri, Trusted, Priority |
  ConvertTo-Json -Depth 4 |
  Set-Content (Join-Path $evidence "before-psresourcerepository-$stamp.json") -Encoding utf8

dotnet nuget list source --format detailed |
  Set-Content (Join-Path $evidence "before-dotnet-sources-$stamp.txt") -Encoding utf8
```

Per SC-0033 all generated evidence belongs under `_generated/`.

### Step 1: PowerShellGet v2 repositories

`Set-PSRepository` updates in place and preserves registration order, so the internal feed
keeps its priority ahead of PSGallery. Prefer it over unregister/re-register.

```powershell
Set-GlobalConfigRootKeys | Out-Null
$settings = Get-HostSettings -hostName $env:COMPUTERNAME

$feedUriByName = @{
  'powershellget-experimental' = $settings['ProGetFeedPowerShellExperimentalUri']
  'powershellget-development'  = $settings['ProGetFeedPowerShellDevelopmentUri']
  'powershellget-integration'  = $settings['ProGetFeedPowerShellIntegrationUri']
  'powershellget-qa'           = $settings['ProGetFeedPowerShellQAUri']
  'powershellget-stable'       = $settings['ProGetFeedPowerShellStableUri']
}

foreach ($name in ($feedUriByName.Keys | Sort-Object)) {
  $uri = $feedUriByName[$name]
  Set-PSRepository -Name $name -SourceLocation $uri -PublishLocation $uri -InstallationPolicy Trusted
}
```

Set `PublishLocation` as well as `SourceLocation`. A repository left with an `http://`
publish location reads correctly but fails on publish.

### Step 2: PSResourceGet repositories

PSResourceGet is a **separate store** with a different URI shape — it appends the `/v2`
OData suffix that PowerShellGet v2 leaves implicit.

```powershell
foreach ($tier in 'experimental', 'development', 'integration', 'qa', 'stable') {
  $name = "powershellget-$tier"
  Set-PSResourceRepository -Name $name -Uri "https://utat022:50000/nuget/$name/v2" -Trusted
}
```

> **Known defect — PSResourceGet cannot consume these feeds (pre-existing, not caused by
> the HTTPS move).** The `/v2` suffix is required for PSResourceGet to *classify* the
> repository, but `/nuget/<feed>/v2` is not a real ProGet route and returns 404 for every
> operation (`Save-PSResource` fails on `/v2/FindPackagesById()`). Registering the bare
> feed URL instead makes PSResourceGet report *"not a known repository type that is
> supported"*, and these PowerShell-type feeds expose no `/v3/index.json`. ProGet serves
> OData v2 **only** at the bare feed URL, which PSResourceGet will not accept.
>
> Keep the `/v2` registration (the historical state) and use PowerShellGet v2
> (`Find-Module` / `Install-Module` / `Save-Module`) for these feeds. Registering them for
> PSResourceGet is currently pointless but harmless; it is retained so the two stores stay
> symmetrical if a future ProGet edition implements the endpoint.
>
> **Tooling already accounts for this.** `Invoke-PromotedModuleTests` was changed in
> `ATAP.Utilities.BuildTooling.PowerShell` **0.1.74** (commit `c826363ae`) to restore the
> promoted package with `Save-Module` instead of `Save-PSResource`. The BuildMaster
> pipeline was never affected — it passes `-ProGetBaseUrl` and takes the direct
> `/nuget/<feed>/package/<name>/<version>` branch — but the feed-restore branch used by
> ad-hoc and local invocations always failed until that fix. On **0.1.74 or later a
> standalone `Invoke-PromotedModuleTests` call works**; on 0.1.73 or earlier it fails with
> a 404 on `/v2/FindPackagesById()`, and the pipeline's own promoted-test result in the
> execution log is the evidence to read instead.

### Step 3: dotnet/NuGet sources

Existing sources are updated with `dotnet nuget update source`; this changes host and
scheme together.

```powershell
foreach ($tier in 'experimental', 'development', 'integration', 'qa', 'stable') {
  $name = "nuget-$tier"
  dotnet nuget update source $name --source "https://utat022:50000/nuget/$name/v3/index.json"
}

foreach ($tier in 'experimental', 'development', 'integration', 'qa', 'production') {
  $name = "releasebundle-$tier"
  dotnet nuget update source $name --source "https://utat022:50000/upack/$name/"
}
```

The `database-*` feeds were never registered as client sources. Add them with
`dotnet nuget add source`:

```powershell
foreach ($tier in 'experimental', 'development', 'integration', 'qa', 'stable') {
  $name = "database-$tier"
  dotnet nuget add source "https://utat022:50000/nuget/$name/v3/index.json" --name $name
}
```

Universal (`upack`) feeds take the bare feed URL. Only NuGet-type feeds take the
`/v3/index.json` service-index suffix.

### Step 4: Repo `NuGet.Config` files

Repo-level configs override user-level ones, so a stale checked-in file silently defeats
Step 3 for anyone building in that repo.

```powershell
Get-ChildItem -Path $repoRoot -Filter 'nuget.config' -Recurse -File |
  Select-String -Pattern 'http://' |
  Select-Object Path, LineNumber, Line
```

Any hit is a repo change that must be committed and reviewed like ordinary source.

## Verification

Registration succeeding is not proof the endpoint works. Verify all four surfaces
independently.

### Every endpoint answers under strict TLS

This is the load-bearing check. It uses default certificate validation — **no**
`-SkipCertificateCheck`, because skipping validation would mask exactly the name-mismatch
failure this migration can introduce.

```powershell
$urls = @()
foreach ($tier in 'experimental', 'development', 'integration', 'qa', 'stable') {
  $urls += "https://utat022:50000/nuget/nuget-$tier/v3/index.json"
  $urls += "https://utat022:50000/nuget/database-$tier/v3/index.json"
  $urls += "https://utat022:50000/nuget/powershellget-$tier/"
}
foreach ($tier in 'experimental', 'development', 'integration', 'qa', 'production') {
  $urls += "https://utat022:50000/upack/releasebundle-$tier/"
}

$results = foreach ($url in $urls) {
  try {
    $response = Invoke-WebRequest -Uri $url -TimeoutSec 25 -ErrorAction Stop
    [pscustomobject]@{ Url = $url; Status = $response.StatusCode }
  }
  catch {
    [pscustomobject]@{ Url = $url; Status = "FAIL: $($_.Exception.Message)" }
  }
}

$results | Format-Table -AutoSize -Wrap
'{0} of {1} OK' -f @($results | Where-Object Status -eq 200).Count, $results.Count
```

Expect `20 of 20 OK`.

### Module resolution works end to end

```powershell
Find-Module -Name 'ATAP.Utilities.BuildTooling.PowerShell' -Repository powershellget-stable
Find-PSResource -Name 'ATAP.Utilities.BuildTooling.PowerShell' -Repository powershellget-stable
```

### No surface left on http

```powershell
Get-PSRepository         | Where-Object SourceLocation -like 'http://*'
Get-PSResourceRepository | Where-Object Uri            -like 'http://*'
dotnet nuget list source | Select-String 'http://'
```

All three must return nothing.

### BuildMaster reachable

```powershell
(Invoke-WebRequest -Uri 'https://utat022:50017/' -TimeoutSec 25).StatusCode   # 200
```

## Rollback

The migration is fully reversible from the Step 0 evidence, but rollback is only useful if
the **servers** are also reverted to HTTP — client registrations pointing at `http://` fail
against an HTTPS-only ProGet.

```powershell
$before = Get-Content (Join-Path $evidence 'before-psrepository-<stamp>.json') -Raw | ConvertFrom-Json
foreach ($repo in $before) {
  Set-PSRepository -Name $repo.Name -SourceLocation $repo.SourceLocation `
    -PublishLocation $repo.PublishLocation -InstallationPolicy $repo.InstallationPolicy
}
```

Roll back dotnet sources with `dotnet nuget update source <name> --source <old-url>`, and
remove the added `database-*` sources with `dotnet nuget remove source <name>`.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `The response ended prematurely (ResponseEnded)` | `http://` request to an HTTPS-only listener | Change the registration to `https://` |
| `The SSL connection could not be established` | Host is `localhost`; cert SAN covers only `utat022` | Change the host to `utat022` |
| `Unable to resolve package source` from `Find-Module` | PSRepository `SourceLocation` still `http://` | Step 1 |
| `Find-Module` works but `Install-PSResource` fails | PSResourceGet store not migrated | Step 2 |
| `dotnet restore` fails after PowerShell feeds work | dotnet sources not migrated, or a repo `NuGet.Config` overrides | Steps 3 and 4 |
| `Get-HostSettings` throws about config root keys | Profile not loaded in this shell | Run `Set-GlobalConfigRootKeys` first |

## Known issue: TLS interception by local antivirus

On workstations running Avast with HTTPS/SSL scanning enabled, the certificate presented
for `utat022:50000` is **not** the ATAP-issued certificate. Avast terminates TLS and
re-issues a substitute:

```text
Subject : C=US, O=ATAP Foundation, CN=utat022
Issuer  : CN=Avast Web/Mail Shield Root, O=Avast Web/Mail Shield,
          OU=generated by Avast Antivirus for SSL/TLS scanning
```

Chain validation *succeeds* only because the Avast root is installed in both
`Cert:\LocalMachine\Root` and `Cert:\CurrentUser\Root`. The consequences:

- Feed traffic is decrypted and re-encrypted by the antivirus on this workstation. HTTPS
  is **not** end to end.
- Validation against the ATAP Foundation or ATAP Consulting root CAs will fail, so
  certificate pinning to the ATAP chain cannot be added while interception is active.
- A genuine certificate problem on the server is masked, because Avast presents a locally
  trusted certificate regardless of the origin certificate's state.

Detect interception on any host with:

```powershell
# Issuer should be an ATAP root, not an antivirus shield root.
$callback = { param($sender, $cert, $chain, $errors) $true }
$tcp = [System.Net.Sockets.TcpClient]::new('utat022', 50000)
$ssl = [System.Net.Security.SslStream]::new($tcp.GetStream(), $false, $callback)
$ssl.AuthenticateAsClient('utat022')
([System.Security.Cryptography.X509Certificates.X509Certificate2]$ssl.RemoteCertificate).Issuer
$ssl.Dispose(); $tcp.Dispose()
```

Package **signing** is unaffected — Authenticode signatures and the package catalog travel
inside the artifact and are verified after download, so TLS interception cannot alter them
undetected. That property is the reason signature verification, not transport trust, is the
authority for artifact integrity.

## Remaining work

The client registrations are migrated and verified. These items are **not** done:

1. **Source-code fallback defaults.** Roughly 52 non-test occurrences across the
   BuildTooling modules still hardcode `http://localhost:50017` (BuildMaster) or
   `http://localhost:50000` (ProGet) as last-resort defaults, plus 37 in test fixtures.
   They are reached only when settings and environment lookups both miss, but at that point
   they now fail rather than degrade. Highest-value targets, because they are live rather
   than fallback:
   - `src/ATAP.Utilities.BuildTooling.CSharp/ATAP.Utilities.BuildTooling.targets`
     (`ProGetBaseUrl`, `ProGetExperimentalFeedUrl` MSBuild defaults)
   - `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/Invoke-CSharpPackageBuildMasterStage.ps1`
   - `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/Invoke-DatabasePackageBuildMasterStage.ps1`
   - `src/ATAP.Utilities.BuildTooling.BuildMaster/Plans/Promote-ReleaseBundleBuildMasterPackage.ps1`

   These three plan runners pass `-ProGetUrl http://localhost:50000` as a literal argument,
   not a fallback. The PowerShell-module pipeline plans are clean.

   Touching about 70 files across several modules meets the R-36 agent-swarm threshold and
   requires re-releasing each affected module, so it is deliberately scoped as separate work.

2. **`database-*` feeds absent from host settings.** Add `ProGetFeedDatabase*` entries in
   `ATAP.IAC` so `ProGetFeedCollection` declares all 20 feeds and registration can be
   driven from settings rather than a literal list.

3. **`NewComputerSetup.md` steps 9.8 and 9.9** documented `http://localhost:50000`
   registration. Updated by this migration; re-verify on the next clean workstation build.

## Related documentation

- [ProGet-Install-Runbook.md](ProGet-Install-Runbook.md)
- [BuildMaster-Install-Runbook.md](BuildMaster-Install-Runbook.md)
- [ConfigRootKeys-and-HostSettings.md](ConfigRootKeys-and-HostSettings.md)
- [NewComputerSetup.md](NewComputerSetup.md) steps 9.8 and 9.9
- [PowerShell-Modules-Pack-and-Publish.md](PowerShell-Modules-Pack-and-Publish.md)
- [Database-Package-Artifact-And-Feed-Decision.md](Database-Package-Artifact-And-Feed-Decision.md)
