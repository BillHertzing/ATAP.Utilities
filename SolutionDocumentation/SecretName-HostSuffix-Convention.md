# SecretName Host-Suffix Convention (SC-0288)

**Status:** Active — adopted Sprint 0013 Task 13.66.
**Applies to:** every ProGet and BuildMaster SecretName in ATAP.Utilities, ATAP.IAC, and their runbooks.

---

## 1. The rule

Every ProGet and BuildMaster SecretName is written in the canonical host-suffixed form:

```text
<BaseName>.<placement-host>
```

The suffix names the host that runs the service the credential authenticates against. There
is one credential per service **instance**, so the SecretName has to identify the instance.

| Base name                    | Service key   | Example on `utat01`                    | Example on `utat022`                    |
| ---------------------------- | ------------- | -------------------------------------- | --------------------------------------- |
| `BuildMaster.Admin.API.Key`  | `BuildMaster` | `BuildMaster.Admin.API.Key.utat01`     | `BuildMaster.Admin.API.Key.utat022`     |
| `ProGet.Admin.API.Key`       | `ProGet`      | `ProGet.Admin.API.Key.utat01`          | `ProGet.Admin.API.Key.utat022`          |
| `ProGet.BuildMaster.API.Key` | `ProGet`      | `ProGet.BuildMaster.API.Key.utat01`    | `ProGet.BuildMaster.API.Key.utat022`    |

SecretNames are **names only**. The value is resolved with `Get-SecretATAP` immediately before
the authenticated operation and never stored, logged, or passed as a raw key (Task 13.62).

### The suffix names the service host, not the calling host

This distinction decides what is in scope, so read it before applying the rule anywhere new.

The suffix identifies **which service instance the credential belongs to** — the host running
that ProGet or BuildMaster server. It has nothing to do with which workstation happens to be
running `Get-SecretATAP`. `Get-SecretATAP` called from `utat01` against a ProGet placed on
`utat022` must resolve `ProGet.Admin.API.Key.utat022`, because that is the credential the
`utat022` server will accept.

### What is NOT host-suffixed

**The discriminator:** ask what the credential proves.

- *"This request may administer the ProGet/BuildMaster instance running on host X"* — per
  **instance**. It takes the suffix, because there is one such credential per instance and the
  host is what tells them apart.
- *"This process is allowed to read secrets at all"* — per **caller**. Its value has nothing to
  do with where any service runs, so suffixing it invents a name that does not exist in the vault.

| Credential | Suffixed? | Why |
| ---------- | --------- | --- |
| ProGet / BuildMaster API keys | **Yes** | One credential per service instance; the instance is identified by its host. |
| `BWS_ACCESS_TOKEN` — the Bitwarden Secrets Manager machine access token (`Get-BWSAccessToken`, provisioned by `Initialize-BWSAccessToken`) | **No** | It is the key *to* the vault, not a key stored *in* it, so there is no SecretName to suffix. It is a DPAPI-encrypted credential file scoped to the running Windows account — already per-account and per-machine by construction. Its value does not change when ProGet or BuildMaster fails over: the same token reads the same project either way. Suffixing it is a category error. |
| `BW_SESSION` — personal-vault `bw` CLI session | **No** | A different boundary entirely (SC-0175): a real interactive user's personal vault, never used by automation, not a CI/infrastructure secret. |
| `dbConnectionString.<Database>.<Host>.<Tier>[.<UserName>]` | **No (database scheme)** | Database connection-string SecretNames encode a SQL host as part of the database identity, not as a ProGet/BuildMaster placement suffix. They still use dotted notation; the historical hyphenated `dbConnectionString-...` form is legacy-only and must not be used for new SecretNames. |

The one-line test: if a credential's correct value does not change when the service moves to
another host, it is not in scope. Do not suffix it, and do not route it through
`Resolve-HostSuffixedSecretName`.

### Why this exists

Discovered during the BuildTooling 0.1.35 release on `utat01`:
`HostSettings.IAC.Fragment.BuildMaster.ps1` hard-coded `BuildMaster.Admin.API.Key`, but the
`utat01` instance required `BuildMaster.Admin.API.Key.utat01`. A suffixless or wrong-host
SecretName does not fail loudly — it resolves to another instance's credential or to nothing,
and the failure surfaces far from its cause.

---

## 2. Where the host comes from

The host is **never** hard-coded. It is derived from the single human-controlled placement
decision, the `ServicePlacementMap` setting:

```powershell
$global:Settings[$global:configRootKeys['ServicePlacementMapConfigRootKey']]
# @{ ProGet = 'utat022'; BuildMaster = 'utat022'; SqlPrimary = 'utat022' }
```

`HostSettings.IAC.Fragment.PackageRepositories.ps1` builds that map from the operator-set
User-scope environment variable `ATAP_SERVICE_PLACEMENT_PRIMARY_HOST` (default `utat022`), under
a parity journal entry. **That fragment is the only place a host name is validated against an
allowlist.** No other code may carry a second host list — a second list drifts, and a drifted
list silently emits the wrong SecretName.

### Adding a host

Adding `utat0NN` to the workspace requires exactly two changes:

1. Extend the allowlist in `HostSettings.IAC.Fragment.PackageRepositories.ps1`
   (`$_servicePlacementPrimaryHost -notin @(...)`).
2. Create the host's secrets in the Bitwarden `CI-Shared` project (Task 13.66.c, HITL).

No BuildTooling function, host-settings fragment, or runbook needs editing. If a change to any
of those turns out to be necessary, that is a defect against this convention.

---

## 3. How code resolves a SecretName

`Resolve-HostSuffixedSecretName` (exported from `ATAP.Utilities.BuildTooling.Common.PowerShell`)
is the single resolver. Every BuildTooling function that accepts a `-*SecretName` parameter
calls it from its BEGIN block, and only when the caller did not bind the parameter:

```powershell
if (-not $PSBoundParameters.ContainsKey('ProGetApiKeySecretName')) {
  $ProGetApiKeySecretName = Resolve-HostSuffixedSecretName `
    -BaseName $ProGetApiKeySecretName -ServiceName 'ProGet' -SettingName 'ProGetAdminApiKeySecretName'
}
```

Resolution order:

1. **The authoritative host setting.** If `-SettingName` resolves to a non-empty value in
   `$global:Settings`, that value wins unchanged. The host-settings fragments already emit a
   host-suffixed SecretName there.
2. **The placement map.** Otherwise `<BaseName>.<placement-host>` is built from
   `ServicePlacementMap[<ServiceName>]`.

An explicitly bound `-*SecretName` argument is always honoured verbatim; the resolver does not run.

### Fail-closed behaviour

The resolver throws — rather than returning a suffixless or guessed name — when ATAP
configuration is loaded but placement cannot be established:

- no `ServicePlacementMap` in settings;
- the service is absent from the map;
- the mapped value is empty or whitespace;
- the mapped value is a loopback placeholder (`localhost`, `127.0.0.1`, `::1`);
- the mapped value is not a valid host-name token.

The host-settings fragments apply the same rule: when the placement-map ConfigRootKey exists,
a missing or malformed placement host stops profile load instead of emitting a suffixless name.

**One documented exception.** In a shell where *no* ATAP configuration exists at all — both
`$global:Settings` and `$global:configRootKeys` are null, as in a bare or hermetic test shell —
the base name is returned unchanged. Such a shell has no ProGet or BuildMaster endpoint
configured either, so it cannot reach a service to authenticate against. The fragments keep the
matching legacy-compatibility branch for an installed `ConfigRootKeys` module that predates
`ServicePlacementMapConfigRootKey`.

### Stale suffixes

A `-BaseName` whose final segment matches a known host has that segment replaced rather than
appended to, so a legacy literal such as `BuildMaster.Admin.API.Key.utat01` follows the map after
a failover. Known hosts are the values in the placement map plus anything passed to `-KnownHost`.
A trailing segment that is not a known host is left intact, so an ordinary base name is never
mangled.

---

## 4. Writing code and documentation against this convention

- **Do** write parameter defaults as the suffixless canonical **base** name
  (`'ProGet.Admin.API.Key'`), and let the BEGIN-block resolver add the host.
- **Do** write `<BaseName>.<service-host>` in prose and runbook tables, or derive the host in
  runbook snippets (`"ProGet.Admin.API.Key.$serviceHost"`).
- **Do not** hard-code `.utat01` or `.utat022` in any function, fragment, plan, or example.
- **Do not** introduce a host allowlist outside the placement-map fragment.
- **Do not** reintroduce raw-key parameters or `PROGET_*` / `BUILDMASTER_*` API-key environment
  variables; those were retired by Task 13.62.
- **Do not** suffix a caller-scoped credential — see "What is NOT host-suffixed" above. The BWS
  access token in particular is identical on every host and must be left alone.

Callers that must operate against a non-placement host (cross-host administration) pass
`-PlacementHost` explicitly, or bind the `-*SecretName` parameter outright.

---

## 5. Related material

- `Runbook-BitwardenServiceAccounts.md` — how `CI-Shared` secrets are created and read.
- `BuildMaster-Install-Runbook.md`, `Runbook-BuildMasterConfiguration.md`, `ProGet-Install-Runbook.md`
  — the host-suffixed names each service expects.
- `NewComputerSetup.md` — host-specific service-account and administrative SecretNames.
- `_Planning/InformationForTheFuture/Task-13.66-SecretName-HostSuffix-Audit.md` — the Task 13.66.a
  audit and the open Task 13.66.c Bitwarden work.
