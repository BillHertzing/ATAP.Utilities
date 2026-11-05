# RPRRSBSI-V5 Protected Authentication and Access Tiers

> **New in V5 (RPRRSBSI-V5-Opus5_5, 2026-11-05).** Records the developer requirements of 2026-11-04: a highly protected sign-in table visible only to ACE administrators, user-visible information separated from it, an investigation of how secure to make it, and anonymous, registered and paying access tiers. Designs are **proposals**; decisions are in [HANDOFF-V5.md](HANDOFF-V5.md).

## 1. Built baseline (checked in SQL)

| Table (V00160/V00180) | Columns | Visibility today |
| --- | --- | --- |
| `ACE.User` | `PhiloteId`, `UserId`, `SaltedAndHashedPassword` (PHC string, default algorithm Argon2id), `EmailHash` (64 hex characters, unique), `HashAlgorithmName`, `PersonId`, `RowVersion` | No grants in the migration. Its metadata appears in the AceCommander diagram viewer, which shows `ACE` and `ATAPUtilities` schema metadata (not row values) to authenticated users holding an exact-project role. |
| `ACE.UserInformation` | `FirstName`, `LastName`, `Email`, `Phone`, `Role` as `varbinary` ciphertext, `EncryptionKeyVersion` (1–2) | Read through `ACE` decrypt procedure (V00170). |
| `ACE.UserSettings`, `ACE.UserPreferences` | theme, dark mode, language, time zone, colour scheme | User-visible. |
| `ACE.UserState` | `Pending`, `Active`, `Suspended`, `Closed` with validity periods | — |

The user-visible split the developer asks for largely exists; what is missing is a **protection boundary** around the credential columns.

## 2. Protected credential schema

- **V5-AUTH-001:** Credential data SHALL live in a separate schema, proposed name `AceAuth`, outside `Ace`, holding `AceAuth.UserCredential(UserId PK/FK, PasswordHash, HashAlgorithmName, HashParameters, EmailLookupKey, CreatedAtUtc, ChangedAtUtc, RowVersion)` and the sign-in security tables in §3.
- **V5-AUTH-002:** No application or user principal has `SELECT`, `INSERT`, `UPDATE`, `DELETE` or `VIEW DEFINITION` on `AceAuth`. A dedicated authentication role executes exactly: `VerifySignIn` (returns pass/fail, `UserId`, and lockout state only), `SetPassword`, `RecordSignInEvent`. ACE administrators may read metadata through an audited administrator role.
- **V5-AUTH-003:** The diagram viewer's fixed schema selection SHALL exclude `AceAuth`, and per-developer schemas ([V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md)) except for their owner, for every non-administrator.
- **V5-AUTH-004:** `ACE.User` keeps only non-secret identity (`UserId`, `PhiloteId`, `PersonId`) plus owner columns (owned by itself, [V5-60](RPRRSBSI-V5-60-Ownership-And-Ace-Copy.md)). Users may read and manage their own `UserInformation`, `UserSettings`, `UserPreferences` through procedures under row-level security.
- **V5-AUTH-005:** `Role` moves out of the encrypted profile: authorization data lives in role/capability tables ([V5-62](RPRRSBSI-V5-62-Organization-Identity-Products-And-Estates.md) §5), never in user-editable profile data.
- **V5-AUTH-006:** The move is a forward migration (copy columns to `AceAuth`, verify, drop from `ACE.User`), with an updated exact-catalog verifier (successor of `Verify_Login_V00160_ExactCatalog.sql`) and an exact-target amendment like the RDB-310 2026-10-29 amendment.

## 3. Security investigation (identify now, decide later)

| # | Area | Current state | Options, roughly in order of effort |
| --- | --- | --- | --- |
| S1 | Isolation | Credentials beside profile data in `ACE` | `AceAuth` schema, no grants, one sign-in procedure (§2) |
| S2 | Password hashing | Argon2id PHC string | Record parameters; a **pepper** held outside the database and resolved by SecretName; rehash on sign-in when parameters change |
| S3 | Email lookup | `EmailHash` described as SHA-256 of the normalized email (`CrossSchema_UserView_Design.md`); migration checks only the format | Replace with a keyed HMAC (key by SecretName): plain email hashes can be reversed by guessing likely addresses |
| S4 | Profile encryption | Application-level ciphertext with key version | Document key custody and rotation; compare with SQL Server Always Encrypted |
| S5 | Brute force | Not present | `AceAuth.SignInAttempt` counters, lockout windows, API rate limiting |
| S6 | Second factor / external sign-in | Not present | TOTP or passkeys; or an external identity provider so no password is stored |
| S7 | Audit | Not present | SQL Server Audit on `AceAuth`; append-only `AceAuth.SignInEvent` |
| S8 | At rest and backups | Not stated | TDE or backup encryption; restricted backup access (ADR-149) |
| S9 | Sessions | Not in the database | Keep session tokens out of the database, or store only hashes |

Recommendation for the first increment: S1, S2 (pepper), S3, S5, S7. Defer S4 changes, S6 and S8 until the product is closer to production use.

## 4. Access tiers

| Tier | Who | Can see |
| --- | --- | --- |
| Anonymous | not signed in (the credential-free `Guest` row, V00160) | A limited set of pages and `ATAPUtilities` template data through read-only procedures or a read model; marketplace listings. Never direct table access. |
| Registered | signed-in user | Own `Ace` rows, organization rows by role, training and gamification ([V5-70](RPRRSBSI-V5-70-Training-And-Gamification.md)), free bolt-ons. |
| Paying | registered user with an active entitlement | Purchased bolt-ons and paid features. |

- **V5-AUTH-010:** Paid status is an `Entitlement` ([V5-15](RPRRSBSI-V5-15-Plugin-DDL-Authoring-And-Marketplace.md) §5), not a column on the user.
- **V5-AUTH-011:** The product goal is to convert anonymous visitors to registered and then paying users; anonymous content must be enough to show the value and the marketplace.
- **V5-AUTH-012:** Payment processing stays outside the database; only provider references are stored.
