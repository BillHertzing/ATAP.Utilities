# BWS/DPAPI migration and rollback runbook

## Purpose and authority

This runbook describes migration from obsolete Password Manager application
access to Bitwarden Secrets Manager `bws`, an application-owned Project, exact
SecretNames, and an identity-bound DPAPI `ReadOnly` access-token envelope.

It authorizes no live host, profile, ACL, service, token, vault, package, feed,
deployment, rollback, or cleanup action. Each operation requires its deployment
owner and applicable human-in-the-loop (HITL) approval. Never record a token or
secret value in a command, journal, log, backup, or evidence.

## Preconditions

- Identify the actual process identity, host, application ID, Project ID/name,
  grouping ID, and exact required SecretNames.
- Confirm the approved local `bws.exe` path/digest and `ReadOnly` Project grant.
- Confirm the identity-specific directory and file ACL/owner policy.
- Stop if a parent `BWS_ACCESS_TOKEN`, Password Manager `BW_SESSION`, `bw`
  application configuration, ReadWrite/plaintext token, unsafe path, or
  unapproved identity/grouping is present.
- Obtain fresh operator-supplied secure input; do not transcode the old credential
  by default.

## Migration phases

| Phase | Reader | Writer | Gate |
| --- | --- | --- | --- |
| 0 — evidence | Existing legacy only | Existing legacy | Ratified contract and deterministic evidence |
| 1 — transition | One exact active file; envelope V1 or explicitly enabled legacy CLIXML selected only by exact marker | Envelope V1 only | Tests pass; each slot is reprovisioned and post-validated |
| 2 — envelope default | Envelope V1; legacy disabled by default and time-bounded for approved rollback | Envelope V1 only | Complete inventory, two successful deployment validations, and 30 days without legacy reads |
| 3 — envelope only | Envelope V1 only | Envelope V1 only | HITL confirms Phase 2 and no open rollback incident |

Writers emit only `AtapBwsDpapiEnvelope` version 1. A transition reader accepts
exact supported PowerShell PSCredential CLIXML only when
`AllowLegacyPowerShellCliXml` is explicitly enabled. It must not invoke
PowerShell or Password Manager `bw`, inspect `BW_SESSION`, guess a format, or
fall through from a malformed envelope to the legacy parser.

## Per-slot migration

1. Stop the application or service that owns the identity/application slot.
2. Reconfirm identity, host, application, Project/grouping, `ReadOnly` purpose,
   canonical filename, local path, ACLs, and no parent-environment credential.
3. Enumerate recognized active candidates once. Zero is missing. More than one,
   including canonical plus legacy or case variants, is ambiguous. Stop on
   missing, unsupported, or ambiguous state; never select newest, closest,
   first, or apparently decryptable.
4. Acquire the bounded per-slot replacement lock and fresh approved secure input.
5. Build the envelope in a bounded buffer with DPAPI `CurrentUser` binding to
   host, effective SID/SAM, application, provider, Project/grouping, version, and
   `ReadOnly`; clear plaintext buffers immediately after protection.
6. Stage ciphertext only in a non-candidate same-directory file with exclusive
   creation, restrictive ACLs, bounded size, and flushed data/metadata.
7. Publish atomically. Preserve at most one ciphertext-only rollback artifact;
   never leave both formats under recognized active names.
8. Reopen through the normal reader and post-validate binding and a bounded round
   trip without invoking `bws` as a format test.
9. Start only after local validation and deployment-owner approval. Validate
   required exact SecretNames and typed failure behavior without exposing values.

On failure, clear owned buffers and remove only an owned unpublished temporary
file. Preserve prior ciphertext rollback. Never auto-restore after identity,
integrity, security, or ambiguity failures.

## Rollback

Rollback is an operator-controlled maintenance/deployment action, not fallback.

1. Obtain the separately approved target, window, owner, and prior immutable
   package/application configuration.
2. Stop the application; never switch provider or format inside a running process.
3. Under the same identity/host, validate the ciphertext-only artifact,
   owner/ACL/path, format, binding, and destination cardinality.
4. Stop on missing, unsupported, corrupt, or ambiguous state. Never overwrite a
   collision or keep two active candidates.
5. Atomically replace the envelope with the approved artifact and enable the
   bounded legacy gate only when the approved rollback requires CLIXML.
6. Start and validate through the approved deployment procedure; record only
   metadata evidence and security consequences.

Rollback never decrypts into a transfer file, republishes a package version,
uses `bw`/`BW_SESSION` as application fallback, or converts BWS failure into
Password Manager behavior.

## Cleanup and retirement boundary

Removing the legacy reader, PowerShell serialization dependency, feature gate,
obsolete APIs/packages, inactive rollback files, or migration-only code is
destructive cleanup. It is prohibited until Phase 3, target/retention inventories
are reviewed, package rollback has ended, and HITL approves every cleanup target.
Historical immutable packages remain evidence and are not deleted by this runbook.

## Evidence and related guidance

- Record only metadata, counts, typed failures, hashes, and redacted results.
- See the [provider guidance](ReadMe.md).
- See the [adversarial test matrix](AdversarialTestMatrix.md) for local evidence
  and remaining target-host gates.
- See the [nearest package index](INDEX.md) and [secrets index](../INDEX.md).
