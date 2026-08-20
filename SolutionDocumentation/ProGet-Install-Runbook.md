# ProGet Install Runbook

> **Task 13.62 security cutover:** Do not create, export, print, or validate a ProGet key through an environment variable as older sections below direct. Use canonical SecretNames `ProGet.Admin.API.Key.<service-host>` and `ProGet.BuildMaster.API.Key.<service-host>` through `Get-SecretATAP`; BuildMaster never falls back to admin.

> **SC-0288 / Task 13.66 host-suffix convention:** `<service-host>` is the host running this
> ProGet instance, taken from the `ServicePlacementMap` setting (`utat01` or `utat022` today).
> Resolve it rather than typing it:
>
> ```powershell
> $serviceHost = $global:Settings[$global:configRootKeys['ServicePlacementMapConfigRootKey']]['ProGet']
> $ProGetAdminSecretName = "ProGet.Admin.API.Key.$serviceHost"
> ```
>
> A suffixless ProGet SecretName is no longer valid. See
> `SecretName-HostSuffix-Convention.md` for the full rule and its fail-closed behaviour.

> **Provenance:** Migrated from `_Planning/Explainers/0002-ProGet-Setup.md` (rows
> `0002-install` and `0002-403`) as part of the Sprint 0007 Explainer Elimination Plan.
> The full historical explainer is being retired; this runbook is now the canonical
> step-by-step install procedure for ProGet on a developer/build workstation.

## Status

| Field                         | Value                                                                                           |
| ----------------------------- | ----------------------------------------------------------------------------------------------- |
| **Installation**              | Complete — ProGet is running                                                                    |
| **Target host**               | `utat022` (all config uses `localhost`)                                                         |
| **SQL Server instance**       | `localhost\PRODUCTION` (or `UTAT022\PRODUCTION`)                                                |
| **ProGet web/API port**       | `50000`                                                                                         |
| **ProGet.config**             | Under Git control in `ATAP.IAC`, symlinked to `C:\ProgramData\Inedo\SharedConfig\ProGet.config` |
| **Database user**             | `NT SERVICE\INEDOPROGETSVC` (db_owner on `ProGet` database)                                     |
| **Feed architecture**         | Phase 1 (combined push+pull feeds per tier) — see Architecture Overview below                   |
| **Build pipeline smoke test** | Complete — `ATAP.Utilities.BuildTooling.CSharp` pushes to `nuget-experimental` on every build   |
| **Admin API key SecretName**  | `ProGet.Admin.API.Key.<service-host>` — resolved only by secure bootstrap/authenticated leaves                 |

---

## Architecture Overview

### Parity journal requirement

Before a step in this runbook changes ProGet, its service account, its host
configuration, or its SQL backing state on `utat022` or `utat01`, append a
secret-safe declaration with `Add-ParityChangeEntry` on the host being changed.
Include the category, item, old/new state, peer host, and a peer action; do not
include any secret value. After the peer applies its corresponding action,
acknowledge it from that peer with `Confirm-ParityChangeApplied`.

ProGet is the internal package repository for all ATAP repositories.

- **Phase 1 (current, canonical for Sprint 0007).** A single combined feed per environment
  tier — each feed accepts both push (publish) and pull (restore/install) traffic.
  Anonymous read access is enabled so `dotnet restore` and `Install-PSResource` work
  without credentials. Writes require an admin API key passed in the `X-ApiKey` header.
  Connectors to public feeds (nuget.org, PowerShellGallery.com) provide transparent
  fallback for packages not present locally.

- **Phase 2 (deferred).** A separate-push-and-pull-feed design with gated promotion and
  per-feed API keys was previously proposed but is **deferred per D-02** in the Sprint
  0007 Explainer Elimination Plan (Section 0a). The Sprint 0007 architecture is permanent
  single-feed-per-tier-per-family; there are no per-sprint feeds.

Both designs use **identical feed names** for the consumer-facing (pull) feeds, so any
future migration to a split-feed design will not require changes to `NuGet.config` or to
`Register-PSResourceRepository` registrations.

## Database content feeds (database-*)

In sprint 0007 a third package family was added alongside the `nuget-*` and
`powershellget-*` feeds: a five-feed family for per-application database
change units. The artifact type is a **NuGet content package** (a regular
`.nupkg` with payload in `contentFiles`), pushed and promoted through the
same immutable-build pipeline that already governs C# and PowerShell
packages. The five feeds are NuGet-type feeds in ProGet, follow the same
push+pull / anonymous-read / `X-ApiKey`-on-write access policy as the
existing `nuget-*` feeds, and do **not** carry a public connector
(there is no upstream public source of these packages).

The five feeds are:

- `database-experimental`
- `database-development`
- `database-integration`
- `database-qa`
- `database-stable`

The full decision record — package-id convention (`<App>.Database`),
package-version convention (SemVer 2.0 with the existing
`Sprint` / `Alpha` / `Beta` / `QA` / _(stable)_ labels), package contents,
promotion direction, and rejected alternatives (Universal Packages) — is
in
[Database-Package-Artifact-And-Feed-Decision.md](Database-Package-Artifact-And-Feed-Decision.md).

> **pgutil not used — replaced by BW CLI + PowerShell REST calls:**
> `pgutil` (Inedo's ProGet CLI tool) is not installed on this host. It was evaluated but
> superseded because it adds an extra dependency: every operation pgutil performs (feed
> management, package promotion, connector setup) can be accomplished with targeted
> `Invoke-RestMethod` calls to the ProGet native API. Secrets and API keys are retrieved
> via the Bitwarden CLI (`bw`). This approach keeps the toolchain minimal and consistent
> with the rest of the automation stack.

---

## Global Configuration Constants

All PowerShell scripts derive ProGet connection details from the shared profile.
**Never hardcode `localhost`, `utat022`, or `50000` in a script body.**

```powershell
# In HostSettings.ps1 (ATAP.IAC repository):
$HostsType1.Add($global:configRootKeys['ProGetHostConfigRootKey'], 'localhost')
$HostsType1.Add($global:configRootKeys['ProGetServiceExePathConfigRootKey'],
    '"C:/Program Files/ProGet/ProGet.exe"')
$HostsType1.Add($global:configRootKeys['ProGetServiceConfigPathConfigRootKey'],
    '"C:/Program Files/ProGet/ProGet.config"')

$HostsType1.Add($global:configRootKeys['ProGetAdminUriSchemeConfigRootKey'], 'http')
$HostsType1.Add($global:configRootKeys['ProGetAdminUriHostConfigRootKey'], 'localhost')
$HostsType1.Add($global:configRootKeys['ProGetAdminUriPortConfigRootKey'], 50000)

# Derived base URL (used by all scripts):
$ub = [UriBuilder]::new(
  $HostsType1[$global:configRootKeys['ProGetAdminUriSchemeConfigRootKey']],
  $HostsType1[$global:configRootKeys['ProGetAdminUriHostConfigRootKey']],
  $HostsType1[$global:configRootKeys['ProGetAdminUriPortConfigRootKey']]
)
$HostsType1.Add($global:configRootKeys['ProGetBaseUrlConfigRootKey'], $ub.Uri.AbsoluteUri)

# Result: $global:ProGetBaseUrl = 'http://localhost:50000/'
```

> **Convention:** All PowerShell scripts that talk to ProGet MUST derive the URL from
> `$global:ProGetBaseUrl` (or its constituent settings). Never hardcode the host or port.

---

## Prerequisites

| Requirement | Details                                                       |
| ----------- | ------------------------------------------------------------- |
| Windows     | Windows 10/11 or Server 2019+                                 |
| .NET        | .NET 8 Runtime (ProGet 2024+ requires it)                     |
| SQL Server  | `localhost\PRODUCTION` (confirmed running 2026-03-17)         |
| Inedo Hub   | Download from [Inedo.com hub](https://inedo.com/hub)          |
| Firewall    | Open TCP `50000` inbound if other machines will access ProGet |
| SQL Browser | Must be running for named instance resolution                 |

### Verify SQL Server connectivity before starting

```powershell
sqlcmd -S 'localhost\PRODUCTION' -E -Q 'SELECT @@SERVERNAME, @@VERSION'
```

Expected: returns `utat022\PRODUCTION` and the SQL Server 2022 version string.

---

## Step 1 — Download and Run Inedo Hub

1. Open a browser and navigate to **[Inedo.com](https://inedo.com/hub)**
2. Click **Download Inedo Hub** (~1 MB bootstrapper)
3. Run `InedoHub.exe` — it self-updates and opens the Inedo Hub UI
4. Sign in or continue (Free tier — a free license key was requested and manually entered during installation)

---

## Step 2 — Install ProGet via Inedo Hub

1. In the Inedo Hub, find **ProGet** → **Install**
2. On the **Database** screen → click **Advanced**
3. Select **Legacy: Specify SQL Server Connection String**
4. Enter: `Data Source=localhost\PRODUCTION; Integrated Security=True;`
5. Press **OK** → **Install**

The installer will:

1. Create the `ProGet` database on `localhost\PRODUCTION`
2. Run database schema migrations
3. Install the ProGet Windows service (`INEDOPROGETSVC`)
4. Start the service

Installation typically takes 2–5 minutes.

### Post-install: Set the web server port

The ProGet.config file controls the listening port. It is stored under Git version
control in the ATAP.IAC repository and symlinked to the ProGet shared config location:

```powershell
# One-time symlink setup:
cd C:\ProgramData\Inedo\SharedConfig
New-Item -ItemType SymbolicLink -Path './ProGet.config' `
    -Target 'C:\Dropbox\whertzing\GitHub\ATAP.IAC\Windows\AnsibleHostInventory\utat022\ProGet.config'
```

The ProGet.config content:

```xml
<?xml version="1.0" encoding="utf-8"?>
<InedoAppConfig>
  <ConnectionString>Data Source=UTAT022\PRODUCTION;Initial Catalog=ProGet;
        Integrated Security=True;TrustServerCertificate=True;Encrypt=Optional</ConnectionString>
    <EncryptionKey>__SET_FROM_BITWARDEN_AT_STARTUP__</EncryptionKey>
  <WebServer Enabled="true" Urls="http://*:50000/"
    UseHttpsRedirection="False" IntegratedAuthenticationEnabled="False" />
</InedoAppConfig>
```

> **Security note:** SQL authentication with `ProGetUser` is no longer the preferred path
> on this host. Use Integrated Security and grant db access to `NT SERVICE\INEDOPROGETSVC`
> using the `Initialize-ProGetSqlServiceLogin` function from the installed PowerShell
> modules. Keep `ProGet.config` under Git with non-secret placeholders, and hydrate the
> encryption key from Bitwarden at startup.

### One-time SQL service-login bootstrap

Run this once after ProGet install and service creation. The
`Initialize-ProGetSqlServiceLogin` function is autoloaded from the installed PowerShell
modules:

```powershell
Initialize-ProGetSqlServiceLogin -Encrypt Optional -TrustServerCertificate
```

This creates the Windows login (if needed), creates the database user in `[ProGet]`, and
grants `db_owner` to `NT SERVICE\INEDOPROGETSVC`.

---

## Step 3 — Verify Installation

1. Open a browser to **http://localhost:50000**
2. You should see the ProGet login page
3. Default admin credentials (first run): Username `Admin`, Password `Admin`
4. **Immediately change the admin password** via Admin → My Profile → Change Password

Verify the database was created:

```powershell
sqlcmd -S 'localhost\PRODUCTION' -E -Q "SELECT name FROM sys.databases WHERE name = 'ProGet'"
```

Expected output: `ProGet`

---

## Step 4 — Create the Admin API Key

Before creating feeds via the API, you need a system-level API key.

1. Navigate to **http://localhost:50000** → Home → Administration → Security → API Keys
2. Click **Create API Key**
3. Configure:

| Field        | Value                                                                     |
| ------------ | ------------------------------------------------------------------------- |
| Key Type     | System (manage/admin ProGet)                                              |
| API Key      | Use the secure one-time bootstrap for SecretName `ProGet.Admin.API.Key.<service-host>`; never display, export, or record the value |
| Display Name | `ProGet Admin API Token`                                                  |
| Description  | `ProGet Admin API Token`                                                  |
| Permissions  | **Full Control (Including Native API)** — check this box                  |
| Expiration   | Does not expire (Free tier: expiration requires Enterprise)               |

4. Click **Save API Key**

> **Critical:** The securely entered value must be the value resolved for
> `ProGet.Admin.API.Key.<service-host>`. Do not copy it through an environment variable,
> transcript, command argument, or evidence artifact. A mismatch returns `403`.

> **Why Full Control?** This is the system admin key. ProGet Free Edition does not
> support feed-scoped privileges, so a feed-specific key type is not available. Full
> Control is correct.

After bootstrap, validate only metadata and a redacted authenticated probe through
a cmdlet that accepts `-ProGetApiKeySecretName 'ProGet.Admin.API.Key.<service-host>'`. Never print
or compare the resolved value. If resolution fails, verify the SecretName, BWS
project grant, service identity, and purpose-specific BWS credential metadata.

---

## Step 5 — Create the 10 Five-Stage Feeds

The canonical lifecycle has five stages: Experimental, Development, Integration, QA,
and Stable. C# packages and PowerShell modules use the same lifecycle, but they use
separate ProGet feed families and package protocols. The Production deployment stage
consumes the `stable` feed; there is no physical `production` feed tier.

### NuGet Feeds for C# Packages

| Feed Name            | Feed Type | Purpose                                      | Public Connector |
| -------------------- | --------- | -------------------------------------------- | ---------------- |
| `nuget-experimental` | NuGet     | Developer and feature-branch packages        | nuget.org        |
| `nuget-development`  | NuGet     | Packages promoted after initial CI           | nuget.org        |
| `nuget-integration`  | NuGet     | Cross-package integration candidates         | —                |
| `nuget-qa`           | NuGet     | QA-validated release candidates              | —                |
| `nuget-stable`       | NuGet     | Stable packages consumed by production builds | nuget.org       |

### PowerShell Feeds for Modules

| Feed Name                    | Feed Type  | Purpose                                      | Public Connector      |
| ---------------------------- | ---------- | -------------------------------------------- | --------------------- |
| `powershellget-experimental` | PowerShell | Developer and feature-branch modules         | PowerShellGallery.com |
| `powershellget-development`  | PowerShell | Modules promoted after initial CI            | PowerShellGallery.com |
| `powershellget-integration`  | PowerShell | Cross-module integration candidates          | —                     |
| `powershellget-qa`           | PowerShell | QA-validated release candidates              | —                     |
| `powershellget-stable`       | PowerShell | Stable modules consumed by production hosts  | PowerShellGallery.com |

The lifecycle tiers are shared, but the feeds are not interchangeable: C# uses the
`nuget-*` family and NuGet protocol, while PowerShell uses the `powershellget-*` family
and PowerShell package semantics. Older `PowershellGallery-*`, `*-testing`, and
physical `*-production` names are retired aliases, not targets for new automation.

### Creation: Manual (Web UI)

For each feed:

1. Navigate to **Feeds → Create New Feed**.
2. Select the feed type shown in the table.
3. Enter the canonical feed name.
4. Click **Create Feed**.
5. Assign public and inter-tier connectors only under the approved connector policy.

### Creation: Automated (PowerShell)

`New-ProGetFeedSet` in `ATAP.Utilities.IAC.Ansible.PowerShell` can create feeds from the
`PackageRepositoriesCollection` in global settings. This runbook describes the desired
configuration; Task 15.180.e.E08 does not query, create, rename, or delete live feeds.

### Phase 1 feed access policy

| Operation              | Authentication                      |
| ---------------------- | ----------------------------------- |
| Pull (restore/install) | Anonymous — no API key required     |
| Push (publish)         | Admin API key via `X-ApiKey` header |
| Promote                | Admin API key via `X-ApiKey` header |

> Anonymous read is enabled on all feeds so `dotnet restore` and `Install-Module` work
> without credentials.

---

## Connector Configuration

### Connectors for public feed fallback

The public connectors are `nuget.org` (`https://api.nuget.org/v3/index.json`) and
`PowerShellGallery.com` (`https://www.powershellgallery.com/api/v2`). Connector
assignment is independent of the lifecycle-name correction and must be verified against
the approved ProGet policy before live mutation.

### Connectors for inter-tier visibility

If the approved connector policy enables inter-tier visibility, each higher canonical
feed points to the immediately lower feed in its own family:

| Higher Tier  | Lower Tier   |
| ------------ | ------------ |
| Development  | Experimental |
| Integration  | Development  |
| QA           | Integration  |
| Stable       | QA           |

Do not connect a `nuget-*` feed to a `powershellget-*` feed. Promotion copies a package
into a tier; connectors only affect visibility and do not replace promotion evidence.
> **API quirk (ProGet 2024, discovered 2026-03-20):** The management API endpoint
> `POST /api/management/feeds/update` requires the feed name **in the URL path**
> (`/api/management/feeds/update/{feedName}`), not in the JSON body. Sending only a body
> with `"name"` returns `404 Feed "" not found`. The connector names in the assignment
> body must exactly match the display names registered in ProGet's connector list.

---

## Acceptance Checklist (Steps 1-5)

- [ ] Inedo Hub bootstrapper downloaded and executed
- [ ] ProGet installed via Inedo Hub against `localhost\PRODUCTION`
- [ ] `INEDOPROGETSVC` Windows service is `Running`
- [ ] `ProGet.config` symlink at `C:\ProgramData\Inedo\SharedConfig\ProGet.config`
      points at the `ATAP.IAC` repo copy
- [ ] `Initialize-ProGetSqlServiceLogin` ran successfully; `NT SERVICE\INEDOPROGETSVC`
      is `db_owner` on the `ProGet` database
- [ ] Web UI reachable at `http://localhost:50000`; admin password changed from default
- [ ] The value securely associated with `ProGet.Admin.API.Key.<service-host>` is registered in **Administration → Security → API Keys**
      with **Full Control (Including Native API)**
- [ ] `ProGet.Admin.API.Key.<service-host>` exists in the approved BWS project and a redacted
      authenticated administration probe succeeds
- [ ] No persistent User, Machine, service, or process-launch ProGet API-key
      environment variable exists
- [ ] All 5 NuGet feeds (`nuget-experimental`, `nuget-development`,
      `nuget-integration`, `nuget-qa`, `nuget-stable`) exist
- [ ] All 5 PowerShell feeds (`powershellget-experimental`,
      `powershellget-development`, `powershellget-integration`, `powershellget-qa`,
      `powershellget-stable`) exist
- [ ] No new automation routes to retired `*-testing` or physical `*-production` names
- [ ] Public connectors are assigned according to the approved connector policy
- [ ] Inter-tier connectors, when enabled, stay within one feed family and join adjacent tiers