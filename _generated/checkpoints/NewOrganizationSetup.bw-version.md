# Setup a New Organization

## Purpose

This document covers **one-time, organization-wide** setup tasks — work that must be done
once for the whole ATAP environment, not on each individual workstation. These tasks
typically create or configure cloud identities, accounts, and shared resources that every
developer computer later consumes.

It is the companion to [NewComputerSetup.md](NewComputerSetup.md), which covers the
**per-machine** bootstrap (worktrees, SQL Server, ProGet, BuildMaster, local service
accounts, and the DPAPI credential files). Where a per-computer step depends on something
created here, that step links back to this document.

## Scope: organization vs. computer

Use this rule of thumb to decide where a task belongs:

- **Organization (this document):** done once, ever. Re-running it for a second computer
  would be wrong or redundant. Examples: creating a Bitwarden account, generating its
  personal API key, registering a DNS name, provisioning a shared cloud resource.
- **Computer ([NewComputerSetup.md](NewComputerSetup.md)):** done once **per machine**.
  Examples: installing SQL Server, creating the local `SvcBuildmaster` Windows account,
  writing the DPAPI-protected credential files that bind to that host and user.

The Bitwarden **accounts and their API keys** are organization-level (created once). The
DPAPI credential files that store those secrets are computer-level (recreated on every
host, because DPAPI binds to the host + Windows identity).

## Important Conventions

- Examples in this document use `bob.smith@acme.com` as the personal developer email and
  Gmail-style aliases for the service accounts. Substitute your own addresses.
- Each service that reads secrets from Bitwarden gets its **own Bitwarden account** for
  isolation and independent revocation — not a shared login.
- Service accounts authenticate to the Bitwarden CLI with a **personal API key**
  (`bw login --apikey`), which is exempt from two-factor authentication. Email/password
  login is 2FA-gated and cannot run unattended. See
  [NewComputerSetup.md §9.4](NewComputerSetup.md#94-manually-provision-dpapi-bitwarden-credentials-for-the-service-accounts) for
  why this matters at runtime.

---

## Phase 1: Bitwarden Accounts

The ATAP automation reads secrets (connection strings, API keys, service credentials)
from Bitwarden via the CLI. This phase creates the Bitwarden identities that the per-host
service accounts will use.

### 1.1 Concepts

The Bitwarden CLI separates two operations:

1. **Login** — authenticates to a Bitwarden account. Can use email/password (2FA-gated)
   or a personal API key (`client_id` / `client_secret`, **not** 2FA-gated).
2. **Unlock** — decrypts the local vault using the account's **master password** and
   returns a session key (`BW_SESSION`).

A service therefore needs **both** the API key (to log in unattended) **and** the master
password (to unlock). The API key alone does not decrypt the vault.

We use **separate Bitwarden accounts per service** rather than one shared account:

- Each service can be granted only the secrets it needs.
- An individual service account can be disabled or re-keyed without affecting the others
  or your personal vault.
- Each runs in its own OS identity and process, so their sessions never collide.

### 1.2 Accounts to create

For the current ATAP environment there are three Bitwarden accounts: your personal
account plus one per service account (`SvcBuildmaster`, `SvcProGet`).

| Bitwarden account       | Email used to register             | Purpose                                                                |
| ----------------------- | ---------------------------------- | ---------------------------------------------------------------------- |
| Personal (you)          | bob.smith@acme.com                 | Interactive vault; also stores the service master passwords + API keys |
| Service: SvcBuildmaster | bob.smith+SvcBuildmaster@gmail.com | BuildMaster automation (SvcBuildmaster Windows user)                   |
| Service: SvcProGet      | bob.smith+SvcProget@gmail.com      | ProGet automation (SvcProGet Windows user)                             |

> If you add a third service later, follow the same pattern: one new Bitwarden account,
> one new email alias, one new personal API key.

### 1.3 Choose the service-account email alias strategy

Each Bitwarden account needs a **distinct, verifiable** email address. You do not need a
separate real inbox per service — route them all into one mailbox you control. Two
strategies, both shown in the table above:

- **Plus-addressing** (e.g. `bob.smith+SvcProget@gmail.com`) — the `+tag` is delivered to
  the base inbox `bob.smith@gmail.com`. No setup required on Gmail or Outlook.com; the
  verification email lands in your main inbox. This is the recommended default.
- **Distinct address / catch-all** (e.g. `SvcBuildmaster@acme.dev` on a catch-all domain) — a fully
  separate address. On Gmail this is a different account you must actually own; on a custom
  domain with a catch-all rule it is just another deliverable alias. Use this when you want
  the service addresses to not visibly share a base mailbox.

Bitwarden only requires that the address is syntactically valid and that you can click the
verification link once. After setup, these inboxes are rarely touched again (see §1.7).

### 1.4 Create each Bitwarden account

Do this once per account in the table (personal first, then each service). Create them all
in one sitting to minimize email round-trips.

1. In a browser, open the Bitwarden sign-up page (**Get Started Free** on
   [bitwarden.com](https://bitwarden.com)).
2. Enter the email address for this account (from §1.2) and choose the server location
   (`bitwarden.com` unless you specifically need `bitwarden.eu`).
3. Click **Sign Up** / **Continue**.
4. Open the verification email Bitwarden sends to that address and click **Verify email**.
5. Set a **strong, unique master password** for the account and complete creation.
6. Record the master password immediately (see §1.6).

After this, signing into the Web Vault at that email shows an empty vault ready for use.

### 1.5 Generate a personal API key for each account

Do this once per account, right after creating it.

1. Sign into the Bitwarden Web Vault **as that account**.
2. Go to **Settings → Security → Keys**.
3. Click **View API key** and enter that account's master password.
4. Bitwarden displays:
   - `client_id` — for a personal API key this has the form `user.<guid>` (stable for the
     account)
   - `client_secret`
   - `scope` = `api`, `grant_type` = `client_credentials`
5. Record `client_id` and `client_secret` (see §1.6).

> **Rotation:** clicking **Rotate API Key** later changes only the `client_secret`,
> invalidates the previous key, and kills any active sessions created with it. After a
> rotation you must update the stored credential on every host (re-run the per-computer
> provisioning in [NewComputerSetup.md §9.4.2 / §9.4.5](NewComputerSetup.md#942-create-the-buildmaster-dpapi-credential-files)).

### 1.6 What to record, and where it goes

For each **service** account, capture four values:

| Value           | Used for                              | Where it is stored on each host               |
| --------------- | ------------------------------------- | --------------------------------------------- |
| Email alias     | Reference / account recovery only     | (not stored on the host)                      |
| Master password | `bw unlock`                           | DPAPI `*_BW_Unlock_Credential.xml`            |
| `client_id`     | `bw login --apikey` (BW_CLIENTID)     | DPAPI `*_BW_ApiKey_Credential.xml` (UserName) |
| `client_secret` | `bw login --apikey` (BW_CLIENTSECRET) | DPAPI `*_BW_ApiKey_Credential.xml` (Password) |

Store the **service accounts' master passwords and API keys inside your personal
Bitwarden vault** (the `bob.smith@acme.com` account) as secure-note items — that is the
organization's master copy. The per-computer steps in
[NewComputerSetup.md §9.4](NewComputerSetup.md#94-manually-provision-dpapi-bitwarden-credentials-for-the-service-accounts) read
these values once during provisioning and write them into DPAPI-protected files bound to
each host and Windows identity. Never commit any of these values to source control or
leave them in plaintext.

### 1.7 Minimal email interaction after setup

Once each account is verified and has an API key, normal CLI automation needs no further
email contact. Day-to-day operation uses only `bw login --apikey` and `bw unlock` against
the DPAPI-stored credentials. You only return to these inboxes to rotate an API key or
recover a master password.

---

## Next steps

With the Bitwarden accounts and API keys in place, proceed to the per-computer bootstrap:

- [NewComputerSetup.md](NewComputerSetup.md) — full workstation setup.
- [NewComputerSetup.md §9.4](NewComputerSetup.md#94-manually-provision-dpapi-bitwarden-credentials-for-the-service-accounts) — the
  service-account + Bitwarden steps that consume the accounts and API keys created here.

> **Future organization-level topics.** As additional one-time, environment-wide tasks are
> identified (shared DNS names, certificate authorities, cloud resource provisioning, etc.),
> add them as new phases in this document rather than in the per-computer runbook.
