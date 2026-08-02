# RRSBS ADR-130: Typed Values, Bindings, and Secret References

Status: Proposed for Wave 1 review

Date: 2026-08-02

Owner: RDB-130 / Task 14.20.b.06

## Decision

RRSBS values are typed at their declared input or output boundary. Values used
for querying, joining, ordering, range checks, cardinality, or integrity are
stored and validated as typed scalar columns. A structured value may be stored
as JSON only when its declared ValueType names a versioned .NET DTO contract,
schema version, validation rule, and compatibility fixtures. A collection is a
declared ordered or unordered value collection, not a delimited scalar or
unbounded JSON convention.

Persistence, serialized DTO contracts, and domain libraries are distinct.
The DTO contract owns JSON shape and schema version; a source-generated
System.Text.Json context serializes and validates that DTO; persistence owns
relational identifiers and constraints; domain code owns behavior. A JSON
payload is opaque to relational queries unless a separate approved projection
materializes declared query values.

A secret value is never stored in RRSBS. A secret-reference value stores only a
validated `SecretName` and, when needed, a non-secret field/selector and
resolver policy identifier. Resolution occurs only at authorized execution
time through `Get-SecretATAP`; it is not part of seed data, publication data,
DTO logging, exception text, plan persistence, or generated evidence. Logs,
telemetry, and hashes may contain the opaque SecretName only when that name is
not itself sensitive; they never contain the resolved value.

Bindings connect a declared PrimitiveInputDefinition to a declared Rule input,
a fixed typed constant, or an explicitly versioned derivation. An editable
binding scope belongs to one Instantiation and compatible occurrence identity.
RollItUp selects exact immutable InputBlockVersions; it resolves/copies the
effective defaults into the published snapshot so later default changes cannot
change a published plan. Compatible successor occurrences may carry bindings
forward. An incompatible add, removal, rename, type change, cardinality
change, or semantic change requires an explicit mapping, default, or removal
choice and blocks publication until resolved.

This ADR is an authored normative authority. It does not authorize schema,
migration, seed, secret resolution, package, feed, live-tier, or consumer
changes.

## Scope and authority

This ADR implements VALUE-01 and the RDB-130 binding contract. It uses the
identity and version terms from
[ADR-100](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md), the typed
Entity-reference boundary from
[ADR-105](RRSBS-ADR-105-Entity-Reference-Contract.md), and the immutable
publication/snapshot boundary from
[ADR-110](RRSBS-ADR-110-Temporal-Versioning.md).

The existing free-form `RuleInstantiationBinding.InputName` implementation is
current-state evidence, not the target binding authority. Existing secret
architecture documents establish the existing resolver context; this ADR does
not replace, configure, or invoke it.

## Normative contract

1. Every input and output has one declared ValueType, cardinality, nullability,
   and validation contract. Numeric, Boolean, UTC temporal, identifier, and
   other query/integrity values use canonical typed representation.
2. A structured ValueType identifies its DTO contract, contract schema version,
   source-generated serializer context, validation entry point, and
   compatibility fixtures. Unknown schema versions and malformed payloads are
   rejected before publication or execution.
3. A Philote reference is a typed Entity/Philote reference with the RDB-105
   physical enforcement pattern. It is not a string GUID hidden inside JSON or
   a free-form text locator.
4. A secret-reference ValueType accepts an opaque SecretName meeting the
   repository naming convention. It stores no secret material, credential,
   connection string, private key, vault token, or resolved-value hash.
5. A PrimitiveInputDefinition is satisfied exactly once per required primitive
   occurrence by one of: a fixed typed constant, an exposed Rule input mapping,
   or an explicitly approved versioned derivation. The mapping declares source
   and target types, cardinality, and any conversion rule.
6. A RuleInputDefinition can feed more than one primitive input only when each
   mapping is explicit and type/cardinality-compatible. A primitive input can
   receive no competing mappings unless its declared cardinality/composition
   contract explicitly permits it.
7. Default precedence is: compatible explicit Instantiation override; selected
   versioned Rule default; otherwise a required-value failure. A default never
   silently overrides an explicit compatible value, and a published snapshot
   records the resolved selected value or exact source version.
8. A binding migration evaluates occurrence identity and declared input
   compatibility. Compatible mappings are proposed for carry-forward;
   incompatible mappings require a user-selected mapping/default/removal
   record. Unresolved required inputs block RollItUp.
9. Secret resolution is late-bound to an authorized executor. It resolves the
   opaque reference through `Get-SecretATAP` and keeps the resolved value out of
   persisted values, DTOs, plans, manifests, logs, errors, and evidence.

## Consequences

Wave 3 must define the ValueType, DTO-contract, input-definition, binding,
occurrence, and version-selection model. Wave 5 must add trusted validation
and uniqueness controls. Wave 6 seed work may use only fictional reference-safe
non-secret values. Wave 8 contracts must expose typed values and explicit
schema versions rather than untyped JSON or free-form `InputName` pairs.

RDB-115 owns atomic publication and concurrency. RDB-140, RDB-145, and
RDB-146 own execution, retry, and approval behavior; they must consume the
opaque secret-reference contract without expanding it into secret storage.

## Negative controls

The eventual model, contracts, and tests must reject each of the following:

1. A queryable numeric, Boolean, UTC temporal, Philote, or enum value is stored
   only as an untyped JSON or text payload.
2. JSON is accepted without a declared DTO contract, schema version,
   source-generated serializer context, validation rule, and compatibility
   fixtures.
3. A malformed, unknown-version, or incompatible JSON payload is published or
   executed by falling back to an untyped dictionary.
4. A Philote reference is persisted as a string, JSON field, or table-name/key
   pair instead of the approved typed Entity/Philote relationship.
5. A secret value, credential, private key, connection string, vault token, or
   resolved secret hash is persisted, seeded, logged, placed in an exception,
   or included in generated evidence.
6. A resolver other than `Get-SecretATAP` is invented for an RRSBS secret
   reference, or a SecretName is resolved during publication merely to validate
   that a secret exists.
7. A required primitive input is left unmapped, mapped twice without declared
   composition semantics, or mapped from a Rule input with incompatible type or
   cardinality.
8. A later Rule default changes a previously published InstantiationVersion or
   cached plan without creating a successor snapshot.
9. An incompatible occurrence/input change silently carries forward a binding
   or converts it by name similarity.
10. A DTO, persistence model, or domain model is substituted for either of the
    other two layers solely because their current fields look similar.

## Acceptance checks

- RDB-210 through RDB-260 specify ValueTypes, versioned DTO contracts,
  typed references, occurrence identity, and trusted constraints consistent
  with this ADR.
- RDB-400 through RDB-470 include positive and negative fixtures for every
  negative control, including invalid JSON schema versions, type/cardinality
  mismatch, unresolved required input, conflicting mapping, and secret-value
  leakage checks.
- RDB-500 seed review proves that no seed contains a real secret, PII,
  credential, private key, connection string, or resolved secret material.
- RDB-600 through RDB-655 demonstrate typed external contracts and reject
  legacy free-form binding or secret-resolution behavior.

## Related authorities

- [ADR-100 glossary and Entity-Philote authority](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [ADR-105 Entity-reference contract](RRSBS-ADR-105-Entity-Reference-Contract.md)
- [ADR-110 temporal and versioning contract](RRSBS-ADR-110-Temporal-Versioning.md)
- [Instantiation tables current-state evidence](ATAPUtilities-Instantiation-Tables.md)
- [SecretName host-suffix convention](SecretName-HostSuffix-Convention.md)
- [Secrets plugin architecture](SecretsPluginArchitecture.md)
