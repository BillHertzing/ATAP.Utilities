# Cross-Schema User View Design

Migration: `V00.01.000303__Create_User_Views.sql`

---

## Purpose

This migration creates three views to support consolidated display and
cross-schema reconciliation of user data:

| View | Schema | Purpose |
|---|---|---|
| `vw_UserFull` | `ATAPUtilities` | Full user row within ATAPUtilities |
| `vw_UserFull` | `AceCommander` | Full user row within AceCommander |
| `vw_UserCrossSchema` | `AceCommander` | Reconciles both schemas on `EmailHash` |

---

## Schema Model

Both `ATAPUtilities` and `AceCommander` share an identical three-table
user structure in the same physical database (`ATAPUtilities`):

```
[User]
  UserId               UNIQUEIDENTIFIER   — stable app-level identity
  EmailHash            CHAR(64)           — SHA-256 hex of normalised email
  SaltedAndHashedPassword  NVARCHAR(500)  — Argon2id PHC string
  HashAlgorithmName    NVARCHAR(50)

[UserInformation]  (FK → User.UserId)
  FirstName            VARBINARY(MAX)     — ciphertext
  LastName             VARBINARY(MAX)     — ciphertext
  Email                VARBINARY(MAX)     — ciphertext
  Phone                VARBINARY(MAX)     — ciphertext
  Role                 VARBINARY(MAX)     — ciphertext
  EncryptionKeyVersion TINYINT

[UserSettings]  (FK → User.UserId)
  PreferredTheme       NVARCHAR(200)      — clear text
  IsDarkMode           BIT                — clear text
  Language             NVARCHAR(200)      — clear text
```

AceCommander rows are seeded from ATAPUtilities via migration
`V00.01.000050__Populate_AceCommander_User_Tables.sql`, using freshly
generated GUIDs for `PhiloteId`/`UserId` but preserving `EmailHash` and
all ciphertext payloads.

---

## Joins

### `vw_UserFull` (both schemas)

```
[User]
  LEFT JOIN UserInformation ON UserId
  LEFT JOIN UserSettings    ON UserId
```

LEFT JOIN ensures that a `[User]` row is always returned even when no
`UserInformation` or `UserSettings` row has been inserted yet.

### `AceCommander.vw_UserCrossSchema`

```
AceCommander.[User]                           (base — always present)
  LEFT JOIN AceCommander.UserInformation      ON UserId
  LEFT JOIN AceCommander.UserSettings         ON UserId
  LEFT JOIN ATAPUtilities.[User]              ON EmailHash (non-NULL only)
  LEFT JOIN ATAPUtilities.UserInformation     ON UserId
  LEFT JOIN ATAPUtilities.UserSettings        ON UserId
```

AceCommander is the left/driving side so that AceCommander users without
an ATAPUtilities counterpart still appear in the view with NULL columns
for the ATAPUtilities side.

---

## Cross-Schema Join Key Choice

`EmailHash` (SHA-256 hex of normalised email) was chosen as the
reconciliation key for these reasons:

- It is stable: it does not change when GUIDs are re-generated during
  schema copy migrations.
- It is indexed on both schemas (`IX_User_EmailHash` /
  `AC_IX_User_EmailHash`), keeping join performance predictable.
- It does not expose PII in query plans or slow-query logs; the raw
  email address remains encrypted.

The NULL guard (`AND ac_u.EmailHash IS NOT NULL`) prevents unintentional
cross-row matches when a user was inserted without an email address.

---

## Security Posture

| Layer | Mechanism |
|---|---|
| **Data at rest** | PII columns (`FirstName`, `LastName`, `Email`, `Phone`, `Role`) stored as `VARBINARY(MAX)` ciphertext via `ENCRYPTBYPASSPHRASE` (SQL Server Triple-DES). |
| **Data in transit** | TLS enforced at the database connection layer. |
| **Client display path** | Application calls `ATAPUtilities.usp_GetDecryptedUserInformation(@UserId, @Passphrase)` to obtain clear-text PII for approved display scenarios. The passphrase is loaded from the application configuration key `UserPii:PassphraseV1` (env var `UserPii__PassphraseV1`). |
| **Non-PII settings** | `PreferredTheme`, `IsDarkMode`, and `Language` are stored as clear text and are directly readable from the views. |
| **Views** | These views expose ciphertext columns as-is. They do not perform decryption. Decryption only occurs in the stored procedure layer, where the caller supplies the passphrase. |

### Key rotation

`EncryptionKeyVersion` tracks which passphrase version encrypted each
row. Zero-downtime rotation re-encrypts rows incrementally and bumps the
version field.

---

## Trade-offs and Alternatives Considered

| Decision | Rationale |
|---|---|
| Views expose ciphertext rather than decrypting inline | SQL `VIEW` objects cannot accept parameters; `DECRYPTBYPASSPHRASE` requires a runtime passphrase. Inline decryption would require a schema-bound passphrase constant, which is a security anti-pattern. |
| AceCommander as the driving side for `vw_UserCrossSchema` | AceCommander is the consumer schema; showing AC rows first matches the display use case. ATAPUtilities side is optionally joined. |
| LEFT JOIN for all child tables | Guarantees no user is silently dropped from the view when child rows are missing (e.g., new users before settings are configured). |
| `EmailHash` as join key instead of direct UserId mapping | UserId namespaces differ by design (see `V00.01.000050`). EmailHash is the only durable, cross-schema stable identifier. |

---

## Migration Replacement / Forward-Fix Guidance

Because views are created with `CREATE OR ALTER VIEW` (wrapped in a
drop-then-create pattern for Flyway idempotency), a forward-fix that
changes the view definition should be applied as a new versioned migration
(e.g., `V00.01.000304__...`) that re-creates the views rather than
modifying this file. This preserves the Flyway checksum chain.
