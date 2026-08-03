# RRSBS ADR-185 — PKIArtifact Metadata-Only Contract

Status: Approved for conceptual design on 2026-08-02. No implementation,
seed, migration, or live PKI operation is authorized by this ADR.

## Decision

`PKIArtifact` is admitted as a future RRSBS kind only as a metadata-only
representation. A PKIArtifact Rule may describe a public certificate, CSR,
trust-anchor reference, certificate policy, or a reference to a separately
managed private key. It must never contain private-key material, an encrypted
private-key blob, a password, a connection string, a token, a secret value, or
an instruction that causes key generation, signing, certificate issuance,
trust-store modification, or deployment.

The executor classification is `metadata-only / no executor`. A later executor
requires a separate security design, per-operation approval, and proof that
the runtime obtains secrets only by `SecretName` through the approved secret
boundary.

## Identity and lifecycle contract

The future Kind has a stable code `PKIArtifact` and a Philote allocated only in
the approved baseline registry. This ADR allocates neither. A RuleVersion
records a content hash and source/artifact provenance; a Manifestation may
record an observed public artifact only after a separately approved collector
proves the artifact contains no private material. Observations are never seed
data and must not be reconstructed as issuance instructions.

## Metadata type catalog

| Field | Type | Required | Constraint |
| --- | --- | --- | --- |
| `artifactClass` | closed enum | Yes | `certificate`, `certificateSigningRequest`, `trustAnchor`, `policy`, or `keyReference` |
| `subjectReference` | string | No | Non-secret identifier; no distinguished-name value that contains personal data unless retention review permits it |
| `issuerReference` | string | No | Public issuer identifier only |
| `serialNumber` | string | No | Public certificate metadata only |
| `thumbprint` | SHA-256 hex | No | Exactly 64 hexadecimal characters when present |
| `notBefore` / `notAfter` | ISO 8601 instant | No | Observed validity interval |
| `keyAlgorithm` | closed enum | No | `RSA`, `ECDSA`, `Ed25519`, or `unknown` |
| `keyReference` | `SecretName` identifier | No | A name only; never a resolved secret or key bytes |
| `provenance` | source-artifact reference | Yes | Immutable SourceArtifact/Version reference |

## Grammar boundary

The eventual grammar is a deterministic metadata document with a fixed field
order and no executable verbs. It validates names, enums, timestamps, and
thumbprint shape. It has no terminal or production that accepts PEM, DER,
PKCS#8, PFX, password, token, command, shell expression, or endpoint
credential content.

## Positive and negative fixtures

| Fixture | Expected result |
| --- | --- |
| Public certificate metadata with a SHA-256 thumbprint and SourceArtifact reference | Accepted as metadata only |
| `keyReference: Security.PKI.SigningKey.UTAT01` without a secret value | Accepted as a reference only |
| PEM block, `BEGIN PRIVATE KEY`, PFX bytes, or base64 key material | Rejected |
| `password`, `token`, connection string, or resolved SecretName value | Rejected |
| `issue`, `sign`, `install`, `import`, `export`, or trust-store command | Rejected |
| Artifact observation represented as a seed | Rejected |

## Deferred boundary

Certificate issuance, CSR generation, private-key lifecycle, certificate
installation, trust-store change, renewal, revocation, backup, recovery, and
package promotion are deferred. They are not implied by PKIArtifact metadata
and remain subject to their own security, live-system, and destructive-action
gates.

## Verification evidence

The RDB-185 evidence must prove that the type catalog and negative controls are
present and that this ADR contains no secret-like values. It cannot claim live
certificate, key, trust-store, or executor behavior.
