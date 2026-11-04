# AceCommander UserLogin relational contract

Status: shared-registry source alignment for independent review, Sprint 0017 task 17.68.e.
V00160 and additive V00170 are reserved by the coordinator. This document authorizes no execution.

## Authority and carrier

Bill approved an empty drop list for Experimental, preserving existing shared
identities, definitions and non-user objects. CATALOG-SCHEMA95 places new login
and organizational tables in the existing ACE schema of the ATAPUtilities
database. SHARED-REGISTRY126 then selects C: one existing shared Philote registry,
ATAPUtilities.Philote in that database. ACE.User.PhiloteId references its
PhiloteId primary key. No new ACE.Philote table is created. Any pre-existing
ACE.Philote is unrelated retained data and is never adopted, dropped or changed.

The migration carrier remains ATAP.Utilities, source directory
Database/Flyway/SQL. Unapplied V00160 keeps its reserved filename/version and
requires ACE and the shared registry to exist; it creates neither schema nor
registry. This is forward creation on the reviewed fourteen-migration chain.
The future execution packet must select dbo.flyway_schema_history explicitly.

The migration preserves its fourteen version/script/checksum guards and
refuses another catalog, missing prerequisites, additional history, any of the
four owned login targets, or an existing shared row at the fixed Guest PhiloteId
before permanent effects. It never adopts or remints a colliding Guest identity.
Only the approved new Guest parent is inserted into the shared registry;
its definitions and all prior rows remain unchanged. No existing identity
table is repurposed and no non-user object is reset.

## Source choices

The retained V4 database investigation sections 3 and 5 and merged design 05
section 2 supply the invariants. Exact legacy physical types come from archived
V00.01.000040__Create_AceCommander_Schema.sql and the current shared models.
V4 changes the contact condition to inclusive OR and requires filtered email
uniqueness and concurrency protection; the archived DDL is not copied as a
whole migration.

The new Guest seed uses the verified row whose Comment is Guest user in
Archive/RPRRSBSI-PreV3/Data/User_Users.csv:

- PhiloteId: 3a7f1b9e-4c2d-4e8f-a5b6-7c8d9e0f1a2b.
- UserId: 5d2e8f3c-1a7b-4c9d-b4e5-6f7a8b9c0d1e.

These are separate identities. The archived AceCommander population script
remapped both through NEWID; the new seed choice does not claim those historical
AceCommander IDs or live Guest presence. Source hashes and the selected CSV
row identity are recorded in Migration43/InputPins.json and Report.json.
Guest has null EmailHash and password, no encrypted profile, default settings
and preferences. Its unchanged PhiloteId is registered once in the existing
shared table; AdditionalIdsStub remains null under the existing shared check.
The shared table has no new CreatedAt field or login-specific constraint.
Checks prevent credentials being attached to this fixed Guest identity or its
Philote being paired with another UserId. Existing owned targets or a colliding
shared Guest PhiloteId are refusal cases, without adoption, reminting or reset.

## Tables and invariants

The four new login tables below belong to ATAPUtilities.ACE. Their parent is the existing shared ATAPUtilities.Philote registry.

| Table | Key and relationship | Contract |
| --- | --- | --- |
| User | PhiloteId clustered primary key/FK to ATAPUtilities.Philote; unique UserId | UserId is the application principal, distinct from PhiloteId |
| UserInformation | UserId primary key/FK | At most one encrypted profile; nonempty Email or Phone, inclusive OR |
| UserSettings | UserId primary key/FK | PreferredTheme nvarchar(200), IsDarkMode bit, Language nvarchar(200), TimeZoneId nvarchar(100) |
| UserPreferences | UserId uniqueidentifier primary key/FK | ColorScheme nvarchar(max), UpdatedUtc datetime2(7) |

User keeps SaltedAndHashedPassword nvarchar(500), EmailHash char(64), and the
physical HashAlgorithmName nvarchar(50). A unique index filters out null email
hashes. Non-null hashes contain exactly 64 hex characters. Credentials are either
both absent or both present; authenticated credentials use the current
Argon2id contract. No password, hash, encrypted PII or developer account is
seeded.

Profile FirstName, LastName, Email, Phone and Role are nullable varbinary(max).
EncryptionKeyVersion is tinyint, defaults to 1 and is checked against 1 and 2,
the explicitly named V1/V2 bindings in current Program.cs/StringConstants.
No key availability is inferred or secret resolved. All encrypted fields in a
row use that selector. Existing-profile edits retain it; rotation is a separate
whole-row transaction. Missing keys, unknown selectors and corrupt non-null
ciphertext must fail in the service/decrypt path. DDL cannot verify ciphertext
authenticity or key consistency without that application contract.

## Profile decryption procedure (V00170)

Source-only additive V00170 creates ACE.usp_GetDecryptedUserInformation in
ATAPUtilities. It requires the existing ACE profile table and exactly one
successful V00160 history row with the reviewed filename. It refuses any
existing object at the procedure name and any existing V00170 history row.
It does not edit V00160, overwrite a procedure, modify data or add grants.
The predecessor guard checks version/script/success, without inventing an
applied checksum or claiming that V00160 has actually run. The execution
packet remains responsible for binding the reviewed artifacts to its target.

Parameters are UserId uniqueidentifier, Passphrase nvarchar(500) and
ExpectedEncryptionKeyVersion tinyint. The only result set has zero or one row:
UserId uniqueidentifier, FirstName nvarchar(200), LastName nvarchar(200),
Email nvarchar(500), Phone nvarchar(50), Role nvarchar(200), and
EncryptionKeyVersion tinyint. A missing profile returns a typed empty rowset.

Expected version must be 1 or 2. The passphrase must contain a non-whitespace
character; whitespace-only Unicode keys are rejected without trimming valid
keys. The procedure captures the selected profile once, rejects an unsupported
or mismatched stored selector before decryption, then decrypts the captured
fields. Null ciphertext remains null. A non-null field that cannot decrypt,
an overlength result or an incomplete UTF-16 code unit yields a fixed safe
error before the result row. All conversion is inside that safe error boundary;
no partial plaintext, raw crypto error, key or ciphertext is emitted.

Safe errors are 61810 for unsupported expected version, 61811 for unavailable
passphrase, 61812 for changed/unsupported stored version, and 61813 for failed
decryption or invalid result shape. These errors contain no sensitive values.
UserId alone is not caller authentication. The service must authenticate the
exact circuit owner before DB/config access, capture the supported selector,
choose its configured key and pass all arguments as parameters. It must
materialize the EXEC result before using in-memory SingleOrDefault; server
LINQ must not be composed over EXEC. A decrypted Role is not an authorization
claim. This procedure establishes no new permission or role assignment.

The [future decrypt fixture](D:/ATAPArtifacts/Sprint0017/Task17.68.e/SharedMigration127/Decrypt-PostState-Fixture.sql)
captures original object/column/history metadata before migration on one
verifier connection and compares it after the separately authorized migration.
Its 13 synthetic cases cover V1/V2, nullable fields, missing profile, wrong key,
version refusals, unavailable/Unicode-whitespace keys, corrupt ciphertext,
overlength plaintext and incomplete UTF-16. Each case owns and rolls back its
transaction. It returns only phase/case counts. No case has run here; actual
SQL behavior, consuming service compatibility and deployment remain unverified.

## Concurrency and application integration

User, UserInformation, UserSettings and UserPreferences each have a non-null
SQL rowversion column named RowVersion. Consumers must map it to byte[] with
IsRowVersion, compare the expected token on mutations, and return Conflict on a
zero-row concurrency update. Rowversion is an opaque database token, not a
clock or user-supplied value.

Application consumers must use the same ACE schema, map all four RowVersion
tokens, use Guid preference UserId and map UpdatedUtc. RegistrationSql60
corrected the raw INSERT physical names to HashAlgorithmName, PreferredTheme
and IsDarkMode and removed the nonexistent OverlayColor column. The parallel
application alignment must also target ACE. Source alignment alone does not
prove model/service compatibility, concurrency behavior or a successful login.

ColorScheme remains nvarchar(max), matching an unbounded current string model
rather than inventing a new length limit. TimeZoneId is a separate nullable
field; the application validates offered IDs against its supported timezone
set. Language and theme values are not silently recast as timezones. Profile
Role is not an authorization claim.

## Organization compatibility

UserId is the principal key and PhiloteId is the FK to the one shared registry.
Login and organizational identities register their PhiloteIds there; UserId,
PersonId and PhiloteId keep their distinct semantics and an explicit account-to-
Person relationship rather than inferred ID equality. New organizational tables
remain in ACE. This migration adds no organization-owned FK, membership,
permission or enrollment. Roles, trusted enrollment and coordinated validity
contracts are not selected by sharing the registry. DEP17/O17.2 consumes this
shared-parent contract without inventing grants or reminting existing IDs.

## Verification and limits

The [shared-registry login fixture](D:/ATAPArtifacts/Sprint0017/Task17.68.e/SharedMigration127/PostState-Fixture.sql)
is source only. On one verifier connection before/after an authorized disposable
migration it captures original object/column/history metadata and the shared
registry's original key set plus AdditionalIdsStub byte lengths and hashes.
It checks all original shared rows remain unchanged, with exactly the approved
Guest parent added and no other additions. It checks four new ACE tables,
24 columns, the cross-schema parent FK, other keys/checks, enabled filtered email
index and credential-free Guest state. Any pre-existing ACE.Philote is retained
as an original object rather than counted as a new login table.
The [current decrypt fixture](D:/ATAPArtifacts/Sprint0017/Task17.68.e/SharedMigration127/Decrypt-PostState-Fixture.sql)
uses the shared registry for every synthetic parent and rolls back each case.
These fixtures emit only phase/case counts, not raw definitions or user data.
Earlier Migration43/MigrationFix51/AceAlignment96/DecryptProcedure103 artifacts
remain frozen history. Neither new fixture has executed here.

Static ScriptDom parsing establishes syntax only. It does not establish
constraint behavior, transactional rollback, an executed fixture, encryption
behavior, consuming service compatibility, or authorization. Future negatives
include duplicate hashes, both contact fields, absent/empty contact, key 0/3,
empty or equal IDs, Guest credential mutation, existing target/Guest conflict,
stale tokens and concurrent registration. No such runtime case has run here.
