# Service Accounts and Bitwarden - Alternatives Considered

**Created:** 2026-05-27
**Status:** Reference companion to `ServiceAccountsAndBitwarden.md`

---

## Purpose

This document preserves the alternatives considered during the service-account Bitwarden
design work, along with the reasons they were discarded or deferred, and the detailed
research-time evaluations of each.

Use the main document, [ServiceAccountsAndBitwarden.md](ServiceAccountsAndBitwarden.md),
for the current baseline decision. Use this file when re-evaluating the architecture in
the future.

---

## Summary Table

| Alternative                                      | Current Disposition        | Reason                                                                                                                          |
| ------------------------------------------------ | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| DPAPI credential files + startup/session refresh | Selected baseline          | Works on the current Bitwarden Free tier, uses existing ATAP infrastructure, and gives per-(host, service-account) blast radius |
| Windows Credential Manager                       | Discarded for now          | Similar provisioning complexity to DPAPI files, but no material operational advantage                                           |
| Bitwarden Secrets Manager                        | Deferred                   | Architecturally cleaner, but unavailable on the current Bitwarden Free tier                                                     |
| Machine-scope `BW_SESSION`                       | Rejected                   | Blast radius is too wide because every process on the host can read the token                                                   |
| Named pipe / local HTTPS proxy                   | Rejected                   | Adds custom infrastructure and a new single point of failure without enough benefit                                             |
| HashiCorp Vault                                  | Rejected for current scale | Operationally heavy compared with the present ATAP needs                                                                        |

---

## Alternative Details

### Windows Credential Manager

#### Windows Credential Manager: What It Offered

- No credential files visible in the filesystem.
- Windows-native storage and PowerShell support through the `CredentialManager` module.

#### Windows Credential Manager: Why It Was Not Selected

- It is still DPAPI-backed, so it does not eliminate the "must run as the target service
  account" provisioning problem.
- Session refresh is still required because the Bitwarden Password Manager CLI still uses
  `BW_SESSION`.
- Operators gain less transparency than the file-backed approach and still do not reduce
  the number of moving parts.

#### Windows Credential Manager: Detailed Evaluation

**How it would work:** The Bitwarden master password is stored in the Windows Credential
Manager under the service account via
`cmdkey /add:BitwardenMasterPwd /user:<svc> /pass:<pwd>` or the `CredentialManager`
PowerShell module. At runtime, `Get-StoredCredential` retrieves the password and calls
`bw unlock`.

**Pros:**

- No credential files on disk to manage.
- Windows Credential Manager ACLs restrict access to the owning account.
- Well-supported by PowerShell (`Get-StoredCredential` from `CredentialManager` module).

**Cons:**

- Credentials stored in Credential Manager are also DPAPI-protected — same provisioning
  complexity as the file-based DPAPI approach.
- Session refresh still required (same `BW_SESSION` TTL problem).
- Less transparent to operators (not file-visible like `.xml` files).
- Requires the `CredentialManager` PowerShell module.

**Verdict:** Viable alternative but offers no significant advantage over the file-based
DPAPI approach. Could serve as a secondary option for services where file-based
credentials are inconvenient.

### Bitwarden Secrets Manager

#### Bitwarden Secrets Manager: What It Offered

- Machine accounts and access tokens designed for CI/CD and service scenarios.
- No `bw unlock` or `BW_SESSION` lifecycle to maintain.
- Cleaner long-term separation between human vault access and service-secret access.

#### Bitwarden Secrets Manager: Why It Was Deferred

- The current Bitwarden organization is on the Free tier and does not support Secrets
  Manager machine accounts.
- Adopting it now would force a licensing change before the rest of the ATAP bootstrap
  work can proceed.

#### Bitwarden Secrets Manager: Revisit Trigger

- Re-open this option immediately if the organization upgrades to Teams or Enterprise.

#### Bitwarden Secrets Manager: Official Bitwarden Guidance

Bitwarden Secrets Manager is a separate product specifically designed for CI/CD and
service accounts:

- Uses **machine accounts** with **access tokens** — no user vault, no `bw unlock`.
- Access tokens are long-lived (configurable expiry) and do not require periodic
  interactive renewal.
- The `bws` CLI (Bitwarden Secrets Manager CLI) retrieves secrets using:
  ```powershell
  $env:BWS_ACCESS_TOKEN = '<machine-account-token>'
  bws secret get <secret-id>
  ```
- Available on **Bitwarden Teams and Enterprise plans**. Not available on Free or
  Families plans.
- Secrets are stored in **Secrets Manager projects**, separate from the personal Password
  Manager vault. Teams must decide which secrets to migrate to Secrets Manager.

#### Bitwarden Secrets Manager: Detailed Evaluation

**How it would work:** A machine account is created in Bitwarden Secrets Manager. An
access token is provisioned for each service account. The service uses
`bws secret get <id>` with `$env:BWS_ACCESS_TOKEN` set — no `bw unlock` required.

**Pros:**

- Purpose-built for service accounts and CI/CD.
- No session expiry / refresh complexity.
- Access tokens have configurable expiry and can be rotated without DPAPI re-provisioning.
- Granular machine account permissions (access only the secrets it needs).
- Clean separation from personal Password Manager vaults.

**Cons:**

- Requires Bitwarden Teams or Enterprise plan.
- Secrets must be migrated from the personal vault to Secrets Manager projects.
- Access token must still be provisioned securely on each host (same bootstrap problem,
  but simpler — just set a single env var).
- Introduces a new CLI tool (`bws` vs. `bw`).

**Verdict:** Architecturally superior. Should be adopted if the current org plan includes
or can be upgraded to Teams tier.

### Machine-Scope `BW_SESSION`

#### Machine-Scope `BW_SESSION`: What It Offered

- Very simple implementation: one token, one refresh path, no per-service setup.

#### Machine-Scope `BW_SESSION`: Why It Was Rejected

- Every process on the host can potentially read the machine-scoped token.
- Audit boundaries are poor because multiple services would share the same Bitwarden
  identity and token.
- A single compromise widens the blast radius to the whole host.

#### Machine-Scope `BW_SESSION`: Detailed Evaluation

**How it would work:** A privileged Task Scheduler job (running as SYSTEM or a dedicated
admin account) runs `bw unlock` at boot using stored credentials, then calls
`[System.Environment]::SetEnvironmentVariable('BW_SESSION', ...)` in Machine scope. All
service accounts inherit the Machine-scope `BW_SESSION`.

**Pros:**

- Simple: one `BW_SESSION` to manage.
- No per-service-account provisioning.

**Cons:**

- Machine-scope `BW_SESSION` is visible to **all** processes on the machine — severe
  blast radius if any process is compromised.
- Token expiry still requires a refresh mechanism.
- Uses a single Bitwarden identity for all services — no per-service access control.

**Verdict:** Acceptable only for single-tenant development machines. Not recommended for
production multi-service hosts.

### Named Pipe / Local HTTPS Proxy

#### Named Pipe / Local HTTPS Proxy: What It Offered

- Services would not hold `BW_SESSION` directly.
- A central broker could provide audit logging and secret mediation.

#### Named Pipe / Local HTTPS Proxy: Why It Was Rejected

- Requires custom software, deployment, monitoring, ACL design, and maintenance.
- Introduces a new local critical dependency for every service.
- If a proper external secrets platform is needed later, Bitwarden Secrets Manager is a
  cleaner path than inventing a custom broker.

#### Named Pipe / Local HTTPS Proxy: Detailed Evaluation

**How it would work:** A small Windows service (or sidecar) running as the interactive
user (or a trusted account) holds the `BW_SESSION`. Other services request secrets via a
loopback named pipe or local HTTPS endpoint.

**Pros:**

- `BW_SESSION` is never exposed to service accounts.
- Central audit log of secret retrievals.
- Token managed in one place.

**Cons:**

- Requires building and maintaining a custom secrets proxy service.
- Single point of failure for all secret access on the host.
- Named pipe / loopback security must be carefully ACL-controlled.

**Verdict:** Over-engineered. Bitwarden Secrets Manager achieves the same architectural
cleanliness without a custom proxy.

### HashiCorp Vault

#### HashiCorp Vault: What It Offered

- Mature machine-authn patterns, leasing, revocation, and audit capabilities.
- Strong long-term architecture for large-scale secret-management needs.

#### HashiCorp Vault: Why It Was Rejected For Now

- Operational cost is much higher than the current problem warrants.
- It would require introducing and operating a new always-on infrastructure service.
- It would also require moving secrets away from the Bitwarden-centric operating model
  already in place.

#### HashiCorp Vault: Detailed Evaluation

**How it would work:** A separate HashiCorp Vault server provides secrets via AppRole or
machine-certificate authentication. Services authenticate without interactive
credentials.

**Pros:**

- Enterprise-grade secret management purpose-built for automation.
- No session expiry in the same sense — authentication is via rotating AppRole secret IDs.
- Rich audit log, dynamic secrets, lease revocation.

**Cons:**

- Significant operational overhead: Vault server must be deployed, HA-configured,
  unsealed, and maintained.
- All secrets must be migrated from Bitwarden to Vault.
- Adds a new system dependency that is critical for every service on every host.

**Verdict:** Over-engineered for current ATAP scale. Keep as a long-term migration target
if secret volume and compliance requirements grow.

---

## Future-Looking Possibilities

These are options that are not viable today but should be re-opened when the listed
trigger conditions become true.

### Object Access Auditing on Credential Files

In a managed Windows environment with domain auditing and a SIEM, enable
`Audit Object Access` and place SACL entries on
`C:\ProgramData\ATAP\BitwardenCredentials\<ServiceAccount>\` so that reads by any
principal other than the owning service account generate Security-channel events. Forward
to SEQ or the central SIEM and alert on unexpected principals.

**Revisit trigger:** ATAP adopts Active Directory or another centralized audit
aggregator, or compliance requirements demand per-file access auditing.

### Group Managed Service Accounts (gMSA) after Active Directory Adoption

If ATAP migrates from local Windows service accounts to Active Directory, move the
service accounts to gMSA so AD manages and rotates the Windows passwords automatically
(typically every 30 days). gMSA accounts cannot be used for interactive logon and are
scoped to specific hosts via the `PrincipalsAllowedToRetrieveManagedPassword` list.

DPAPI credential files still need to be re-provisioned on each gMSA password rotation
(ideally by the same scheduled task that performs the Bitwarden session refresh), but
the human service-password-rotation workflow described in
`ServiceAccountsAndBitwarden.md` R-05 goes away.

Combined with object access auditing above, the (gMSA + DPAPI + auditing) model gives:

- AD-managed Windows credentials (no human-managed service passwords).
- Per-(host, service-account) DPAPI scoping for Bitwarden material.
- Per-access logging for unexpected reads.

**Revisit trigger:** ATAP adopts Active Directory, or a compliance/audit requirement
mandates managed service account credentials.

---

## Revisit Conditions

Re-open the discarded or deferred alternatives if any of these become true:

- The organization upgrades Bitwarden licensing and Secrets Manager becomes available.
- ATAP needs stronger centralized audit, dynamic secrets, or policy-driven lease
  revocation than the current Bitwarden Password Manager CLI path can provide.
- The number of hosts and service accounts grows to the point that per-account DPAPI
  provisioning becomes a larger burden than introducing a more centralized platform.
- ATAP adopts Active Directory or a SIEM that supports object access auditing — see
  Future-Looking Possibilities above.
