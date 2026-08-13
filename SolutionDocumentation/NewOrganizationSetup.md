# Setup a New Organization

## Purpose

This document covers **one-time, organization-wide** setup — work done once for the whole
ATAP environment, not on each workstation. It provisions the Bitwarden identities,
projects, and access tokens that every developer computer and every service later
consumes.

It is the companion to [NewComputerSetup.md](NewComputerSetup.md), which covers the
**per-machine** bootstrap (worktrees, SQL Server, ProGet, BuildMaster, local service
accounts, and the DPAPI-protected access-token files). Where a per-computer step depends
on something created here, that step links back to this document.

## Scope: organization vs. computer

- **Organization (this document):** done once, ever — Bitwarden org, users, collections,
  Secrets Manager projects, machine accounts, access tokens, and the secret values
  themselves. Re-running any of it for a second computer would be wrong.
- **Computer ([NewComputerSetup.md](NewComputerSetup.md)):** done once **per machine** —
  install the `bws` CLI and DPAPI-store the relevant machine-account **access token** for
  each Windows service account on that host; and (for the interactive PM user) provision
  the `bw` login/unlock DPAPI files per the 9.4.1–9.4.9 pattern.

## Architecture: two Bitwarden products, two roles

| Product | Role | Identities | Runtime credential |
| --- | --- | --- | --- |
| **Password Manager** (PM) | Human + break-glass storage; interactive vault access. | 2 org **users** | master password (interactive) |
| **Secrets Manager** (BWS) | The runtime secret store for services. | 3 **machine accounts** | scoped **access token** (`BWS_ACCESS_TOKEN`) |

Services authenticate to BWS with a machine-account **access token** via the `bws` CLI —
**no login, no unlock, no `BW_SESSION`, no master password, no 2FA, no session-refresh
task**. The DPAPI-protected access token *is* the entire runtime credential. Password
Manager is used by humans (interactive `bw`) and to hold break-glass copies.

Interactive users who need project secrets should use their own scoped BWS access token
with the same DPAPI file pattern as service accounts. Do not duplicate the same
secret-name/value pairs in both Password Manager and Secrets Manager: project/runtime
secrets live once in Secrets Manager, while Password Manager remains for user-unique
secrets and login-time `BW_SESSION` access.

> **Free-tier limits (verify current values at signup):** PM free org ≈ **2 users / 2
> collections**; BWS free ≈ **2 users / 3 machine accounts**. The design below uses all 3
> machine-account slots and maps any additional Windows services onto them. A Windows
> service identity is **not** the same as a Bitwarden identity.

## Conventions

- Examples use `bob.smith@acme.com` (personal) and Gmail-style `+` aliases for the second
  user; substitute your own. Org/project/machine-account names below are the canonical
  ATAP names — keep them.
- The second human user's alias is chosen so its 2FA email lands in the operator's own
  inbox (e.g. `bob.smith+DeveloperTwo@acme.com`).

---

## Phase 1: Password Manager — org, users, collections (humans + break-glass)

### 1.1 Organization and users

| Slot | Bitwarden user (PM) | Windows identity | Access |
| --- | --- | --- | --- |
| User 1 (owner) | Developer1 — `bob.smith@acme.com` (existing personal account) | operator's interactive login | `bw`, interactive |
| User 2 | DeveloperTwo — `bob.smith+DeveloperTwo@acme.com` | Windows user `DeveloperTwo` | `bw` login/unlock to the org vault, interactive/automated |

`DeveloperTwo` is a **Windows interactive user** configured as the 2nd Bitwarden PM user
with access to the org collections. On a workstation it is provisioned with the `bw`
login/unlock DPAPI pattern documented in
[NewComputerSetup.md §9.4.1–9.4.9](NewComputerSetup.md#94-manually-provision-dpapi-bitwarden-credentials-for-the-service-accounts).

Steps:

1. As Developer1, create a free **Organization** named `ATAP Infra`.
2. Create the second Bitwarden account `bob.smith+DeveloperTwo@acme.com` (verify its email,
   set a strong master password), then **invite/confirm** it into the org as the 2nd user.
3. Record both master passwords (see 1.3).

### 1.2 Collections (max 2 on free tier)

| Collection | Purpose | Members |
| --- | --- | --- |
| `Infra – Admin & Breakglass` | Control-plane + emergency creds: BWS machine-account **access tokens** (backup copies), SM/PM admin tokens, root/SA DB logins, break-glass admin accounts. | Developer1 + DeveloperTwo |
| `Infra – Dev & Tooling` | Shared dev/test credentials humans use interactively: non-prod logins, developer PATs, tool UI logins. | Developer1 (+ optional DeveloperTwo) |

Everything **runtime/service** lives in Secrets Manager (Phase 2); Password Manager holds
**backups and interactive human logins** only.

### 1.3 What to record

Store the second user's master password and every BWS machine-account access token (Phase
2) as items in `Infra – Admin & Breakglass`. That collection is the org's break-glass
master copy. Never commit any of these to source control.

---

## Phase 2: Secrets Manager — projects, machine accounts, tokens (service runtime)

### 2.1 Enable Secrets Manager

Enable Secrets Manager for the `ATAP Infra` org and add Developer1 as an SM user (the
admin who creates projects, secrets, and machine accounts). DeveloperTwo can be added as a
second SM user later if a second human operator is needed.

### 2.2 Projects (group secrets by concern / blast radius)

| Project | Holds (examples) |
| --- | --- |
| `BuildMaster-Core` | `BuildMaster.DB.ConnectionString.Primary`, `Windows.ServiceAccount.BuildMaster.Password`, `BuildMaster.Admin.ApiKey`, `ProGet.ApiKey.ForBuildMaster` |
| `ProGet-Core` | `ProGet.DB.ConnectionString.Primary`, `Windows.ServiceAccount.ProGet.Password`, `ProGet.Admin.ApiKey` |
| `CI-Shared` | cross-tool secrets: `GitHub.CI.PersonalAccessToken`, registry creds, `SMTP.CI.ServiceAccount.Password` |
| `AceCommander-Core` | `AceCommander.Encryption.Key1`, `AceCommander.Encryption.Key2`, `AceCommander.ServiceAccount.Password` |
| `Jenkins-Core` *(future)* | Jenkins controller/agent creds |
| `Ansible-Core` *(future)* | Ansible controller + vault creds |
| `BoltOns-Blender` *(future)* | Blender and other add-on keys |

Start with `BuildMaster-Core`, `ProGet-Core`, `CI-Shared`, `AceCommander-Core`; add the
future projects when those systems go live.

### 2.3 Machine accounts (all 3 free-tier slots used)

| Machine account | Project access | Consumed by (Windows service accounts) |
| --- | --- | --- |
| `SvcBuildMaster` | `BuildMaster-Core`, `CI-Shared` (read) | `SvcBuildMaster` |
| `SvcInfraShared` | `ProGet-Core`, `CI-Shared` (read) | `SvcProGet`, future Jenkins/Ansible agents |
| `AceCommander` | `AceCommander-Core` (read) | AceCommander service / IIS impersonation |

> A Windows service that needs **no** secrets gets **no** machine-account token. Additional
> future services that need shared CI/infra secrets map onto `SvcInfraShared` rather than
> consuming a new slot.

### 2.4 Generate access tokens

For each machine account, create **one access token** in the web vault (Secrets Manager →
Machine accounts → the account → Access tokens). The token is shown **once** — record it
immediately. These tokens are the only runtime credentials.

- Drop a **break-glass copy** of each token into PM collection `Infra – Admin & Breakglass`.
- Create a project-scoped BWS access token for each interactive user that needs to read
  shared project secrets from Secrets Manager instead of from Password Manager.
- The per-host DPAPI storage of these tokens happens in
  [NewComputerSetup.md §9.4](NewComputerSetup.md#94-manually-provision-dpapi-bitwarden-credentials-for-the-service-accounts).

> **Rotation:** regenerating a machine-account token invalidates the previous one. After
> rotation, update the DPAPI token file on every host that uses that machine account.

### 2.5 Populate secrets

Create the secrets in their projects using the naming convention in Phase 3. Migrate the
existing values (DB connection strings, ProGet/BuildMaster admin API keys, Windows/SQL
service-account passwords) into the matching project.

---

## Phase 3: Secret key naming convention

Secret **keys** follow `<System>.<Area>.<What>` (these keys are what
`Get-SecretATAP -SecretName` resolves against the project):

| Kind | Example keys |
| --- | --- |
| Connection strings | `BuildMaster.DB.ConnectionString.Primary`, `ProGet.DB.ConnectionString.Primary` |
| Windows service logins | `Windows.ServiceAccount.BuildMaster.Password`, `Windows.ServiceAccount.ProGet.Password` |
| SQL service logins | `SQL.ServiceAccount.BuildMaster.Password`, `SQL.ServiceAccount.ProGet.Password` |
| Admin API keys | `BuildMaster.Admin.ApiKey`, `ProGet.Admin.ApiKey` |
| Cross-tool keys | `ProGet.ApiKey.ForBuildMaster` (BuildMaster→ProGet), stored in `BuildMaster-Core` |
| AceCommander | `AceCommander.Encryption.Key1`, `AceCommander.Encryption.Key2` |

> **Paired credentials (username + password):** BWS secrets are single-valued. Whether a
> service login is stored as two keys (`….Username` / `….Password`) or as a JSON value is
> decided per-secret during migration; the `Get-SecretATAP` provider supports both.

---

## Identity mapping (the key idea)

```text
Identity                       Bitwarden identity        Access path
---------------------------    --------------------      -----------------------------
Developer1 (you)           ->  PM User 1                 bw, interactive
Windows user DeveloperTwo  ->  PM User 2                 bw login/unlock (9.4.1-9.4.9 pattern)

SvcBuildMaster (service)   ->  BWS machine SvcBuildMaster -> BuildMaster-Core, CI-Shared
SvcProGet (service)        ->  BWS machine SvcInfraShared -> ProGet-Core, CI-Shared
AceCommander svc / IIS     ->  BWS machine AceCommander   -> AceCommander-Core
future Jenkins/Ansible     ->  BWS machine SvcInfraShared -> their *-Core (+CI-Shared)
```

A Windows **service** account fetches secrets with its machine-account **access token**
(`bws`); a Windows **interactive** user (DeveloperTwo) reads the PM vault with `bw`. Only
introduce a separate machine account where a hard blast-radius boundary is required —
otherwise additional services share `SvcInfraShared`.

---

## Next steps

With the org, projects, machine accounts, and tokens in place:

- [NewComputerSetup.md](NewComputerSetup.md) — per-workstation bootstrap.
- [NewComputerSetup.md §9.4](NewComputerSetup.md#94-manually-provision-dpapi-bitwarden-credentials-for-the-service-accounts)
  — install `bws` + DPAPI-store each host's machine-account access token, and provision the
  interactive PM user (DeveloperTwo) via the `bw` login/unlock pattern.

> **Future organization-level topics** (shared DNS, certificate authorities, cloud
> resource provisioning) belong here as new phases, not in the per-computer runbook.

---

## Appendix A: Compute inventory and third-party software model (migrated from the ATAP.IAC ReadMe, 2026-07-06)

> Conceptual design content extracted from the ATAP.IAC repository ReadMe during
> the Task 12.45.c documentation reorganization. ATAP.IAC holds the **data** for
> this model (the `ansibleInventory` object and host settings fragments); the
> concepts live here. Cross-reference: the Task 12.24.e organization-layer
> enumeration (`PLanUTAT01Onboarding.md` §1.5) is the measured, current-state
> counterpart of this design; `ATAP.IAC/ansible/inventory` is designated as the
> first machine-readable home for the role→computer assignment map.

### A.1 The ansibleInventory object

The ATAP.IAC package defines the compute resources of an organization, its
compute-users, and the assignment of users to resources. The `ansibleInventory`
object defines the organization's compute inventory. On the compute-resource
side, Info data structures are defined for hosts, AnsibleGroups, AnsibleRoles,
Chocolatey packages, PowerShell modules, and NuGet packages; all of these may
carry RegistrySettings, GlobalSettings, ScheduledJobs, and PKISecurityCertificates.
The organization's hosts file (IP connectivity) is part of the package.

### A.2 Keyhole/key permission model

The security data structures are entwined with the user data structures: a
collection of users, a collection of compute resources, and a keyhole/key map
specifying the level of permission a user has to utilize a resource. The compute
resource holds the keyhole (an exclusion lock keeping users out of the
resource/feature); it accepts a request to use the resource in a given manner
only if the key fits — the key being a passing test for a specific permission
assigned to a specific user on a specific host. Permissions must be re-evaluated
periodically (tens of seconds), on demand, and via full re-evaluation.

### A.3 Third-party software (SWBOM) property structures

The organization should maintain an approved list of third-party software and a
process to keep it updated. Changes actuate through delivery of packages from
production package-repository hosts. The SWBOM data structures compose as:

- `commonProperties`: RegistrySettings (`hashtable<string,hashtable<string,string>>`),
  GlobalSettings, ScheduledJobs, PKICertificates
- `commonInstallableProperties`: Name (string), version (SemanticVersion),
  allowPrerelease (bool), additional_parameters? (object), Notes? (string)
- `packagingProperties` (has commonInstallableProperties + commonProperties):
  NuGetPackages, ChocolateyPackages, wingetPackages
- `packageProviderProperties` (has packagingProperties + both common sets):
  packageProvider, pushUri, pullUri
- `AnsibleRoleNames` / `AnsibleGroupsNames` (have commonInstallableProperties +
  commonProperties): Meta, Plays/Roles/Packages (TBD)

### A.4 Scheduled maintenance windows

Every computer in the organization wakes at least once every 24 hours and runs
maintenance tasks. Initial schedule: the production package-repository computer
(utat022) wakes at 05:55 and runs its housekeeping script at waketime + 5
minutes; other computers wake 10 minutes after the package-repository host and
run housekeeping at their waketime + 5 minutes. An organization spanning time
zones will eventually need a rotation schedule.
