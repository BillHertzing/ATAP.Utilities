# Service Accounts and Bitwarden - Alternatives Considered

**Created:** 2026-05-27
**Status:** Reference companion to `ServiceAccountsAndBitwarden.md`

---

## Purpose

This document preserves the alternatives considered during the service-account Bitwarden
design work, along with the reasons they were discarded or deferred.

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

### Machine-Scope `BW_SESSION`

#### Machine-Scope `BW_SESSION`: What It Offered

- Very simple implementation: one token, one refresh path, no per-service setup.

#### Machine-Scope `BW_SESSION`: Why It Was Rejected

- Every process on the host can potentially read the machine-scoped token.
- Audit boundaries are poor because multiple services would share the same Bitwarden
  identity and token.
- A single compromise widens the blast radius to the whole host.

### Named Pipe / Local HTTPS Proxy

#### Named Pipe / Local HTTPS Proxy: What It Offered

- Services would not hold `BW_SESSION` directly.
- A central broker could provide audit logging and secret mediation.

#### Named Pipe / Local HTTPS Proxy: Why It Was Rejected

- Requires custom software, deployment, monitoring, ACL design, and maintenance.
- Introduces a new local critical dependency for every service.
- If a proper external secrets platform is needed later, Bitwarden Secrets Manager is a
  cleaner path than inventing a custom broker.

### HashiCorp Vault

#### HashiCorp Vault: What It Offered

- Mature machine-authn patterns, leasing, revocation, and audit capabilities.
- Strong long-term architecture for large-scale secret-management needs.

#### HashiCorp Vault: Why It Was Rejected For Now

- Operational cost is much higher than the current problem warrants.
- It would require introducing and operating a new always-on infrastructure service.
- It would also require moving secrets away from the Bitwarden-centric operating model
  already in place.

---

## Revisit Conditions

Re-open the discarded or deferred alternatives if any of these become true:

- The organization upgrades Bitwarden licensing and Secrets Manager becomes available.
- ATAP needs stronger centralized audit, dynamic secrets, or policy-driven lease
  revocation than the current Bitwarden Password Manager CLI path can provide.
- The number of hosts and service accounts grows to the point that per-account DPAPI
  provisioning becomes a larger burden than introducing a more centralized platform.
