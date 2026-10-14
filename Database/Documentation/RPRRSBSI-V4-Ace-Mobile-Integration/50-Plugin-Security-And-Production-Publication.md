# RPRRSBSI V4 Plugin Security and Production Publication Specification

Status: security architecture requirements. The production publication pathway remains
disabled until its `HITL-PENDING` decisions are ratified and implemented.

## Plugin trust policy

A plugin is untrusted input even when signed. Admission requires all of the following:

1. package and manifest hashes match;
2. every required signature is valid for the package content and target platform;
3. the signer chains to a currently trusted publisher identity;
4. the certificate/key and package are not revoked;
5. the package version, host range, dependencies, and DTO/database contracts are
   compatible;
6. requested permissions are valid, available, and authorized by policy and user
   consent;
7. static, dependency, malware, and policy scans pass; and
8. the package is explicitly allowed for the device, user, tier, and purpose.

Authenticode is an accepted initial layer where technically applicable. The release
format SHALL support additional package/manifest signatures so Android, iOS, and future
devices do not depend on Windows-only verification semantics. Initial self-signed ATAP
Foundation and ATAP Consulting trust roots require a signed update path and an explicit
transition plan to commercial certificates.

## Permission model

Permissions SHALL be granular, declarative, and host-mediated. Candidate categories
include local file roots, activity sources, location precision, local analysis records,
network destinations, central API operations, sidecar output, notifications, and bounded
resource consumption.

- Signature trust SHALL not grant any permission.
- User consent SHALL not grant a capability unavailable under host policy.
- A plugin SHALL not request database DDL, arbitrary SQL, secret value retrieval,
  unrestricted network, process execution, or another user's data through ordinary
  runtime permissions.
- Stored consent SHALL bind plugin publisher and package identity, permission set, user,
  device, and expiry/review policy. A materially changed request requires new consent.

## In-process risk controls

The accepted initial host is in-process, so these compensating controls are mandatory:

- no direct database connection or secret-provider handle is exposed to plugin code;
- data access uses capability-limited host interfaces and minimized DTOs;
- execution has cancellation, time, memory, I/O, and output-size budgets;
- host calls and plugin results are validated at both sides of the boundary;
- plugin threads/tasks cannot outlive the authorized execution context;
- load, unload, crash, timeout, permission denial, and integrity failure are audited;
- repeated faults trigger circuit breaking/quarantine; and
- the architecture preserves a future out-of-process/sandbox adapter.

## `ModifyPlugin` threat model

`ModifyPlugin` combines code authoring, DDL, data fixtures, and supply-chain input. Its
principal threats include:

| Threat | Required control |
| --- | --- |
| Cross-schema DDL | Parse resolved object graph; allow only candidate-workspace Ace objects; deny three-part names and unapproved schemas. |
| Privilege escalation | Deny role/user/login/permission/ownership/trustworthy/assembly security changes. |
| Data exfiltration | Synthetic or user-authorized fixtures only; deny linked servers, external tables, arbitrary network, and secret access. |
| Persistence or trigger abuse | Allowlisted object kinds, bounded trigger rules, recursion/resource limits, and adversarial migration tests. |
| Destructive migration | Forward-only package, disposable validation, explicit affected-object inventory, backup/recovery plan, and new forward fix. |
| Dependency substitution | Lock dependencies and sources; verify hashes, signatures, provenance, and licenses. |
| Malware in plugin bytes | Multi-engine scanning where approved, static analysis, sandbox behavior tests, and independent review. |
| User-to-user leakage | Isolated workspace, owner-scoped fixtures, row-policy tests, and no shared-Ace apply from the authoring principal. |
| Evidence tampering | Content-addressed immutable candidate and independently stored signed evidence manifest. |

## Candidate package contract

An immutable candidate contains:

- candidate, plugin, user/owner, and change-workspace identities;
- source repository/commit and reproducible build provenance;
- parent Ace schema version and required ATAP reference version;
- normalized forward-only Ace DDL and affected-object graph;
- proposed data/reference rows separated from user test data;
- plugin assemblies/resources and signed permission manifest;
- dependency and software-bill-of-materials inventory;
- hashes and signatures for every file;
- fresh, upgrade, negative, tenancy, performance, recovery, and malware evidence; and
- declared limitations, unresolved findings, and expiry.

Passing candidate validation authorizes neither shared-Ace deployment nor ATAP
publication.

## Ace deployment gate

The shared-Ace apply principal SHALL:

1. verify candidate immutability and parent version;
2. verify that no object targets `ATAPUtilities`;
3. verify parity-manifest effects and user-segmentation coverage;
4. take the required recoverable checkpoint;
5. apply the next unused Ace migration version;
6. run post-apply schema, isolation, and semantic checks; and
7. record deploy-state evidence.

The authoring user, plugin process, ordinary AceCommander runtime, and Outpost principals
shall not possess this capability.

## `productionPublishNewOrModifiedPLugin` security boundary

This is the only allowed Ace-to-ATAP DDL/data path. It SHALL satisfy these minimum stages:

1. **Intake:** pull an immutable candidate by digest; do not accept mutable workspace
   paths or caller-supplied destination SQL.
2. **Eligibility:** verify ownership/stewardship, source history, required reviews,
   licenses, supported purpose, and absence of unresolved blocking findings.
3. **Independent rebuild:** reproduce plugin/package bytes in an isolated trusted build
   environment where feasible and compare results.
4. **Security analysis:** signature, dependency, secret, malware, static, dynamic,
   fuzz/negative, DDL allowlist, resource, and data-classification checks.
5. **Semantic review:** confirm expert-system behavior, same-`RuleId` overlay semantics,
   deterministic output, explanations, and registered identities.
6. **ATAP translation:** construct a new ATAP-owned migration/reference package from an
   allowlisted model. Do not replay Ace DDL blindly against `ATAPUtilities`.
7. **Approval:** bind named authorized reviewers to the exact package digest and target
   predecessor. Approval cannot be inherited from Ace deployment.
8. **Tier promotion:** promote identical immutable bytes through Experimental,
   Development, Integration, QA, and explicitly approved Stable/Production gates.
9. **Post-publication:** record provenance, monitoring, rollback-by-forward-fix,
   revocation, and device/plugin update implications.

## Required authorization separation

| Capability | Principal |
| --- | --- |
| Read published ATAP reference data | Normal bounded reader |
| Write user Ace data | User-scoped Ace runtime writer |
| Author plugin candidate | Short-lived `ModifyPlugin` workspace principal |
| Apply shared Ace migration | Ace deployment principal |
| Submit publication candidate | Candidate-submission capability |
| Approve publication | Human/reviewer role, no deployment credential |
| Build ATAP package | Isolated publication builder |
| Apply/promote ATAP package | ATAP deployment principals by tier |

No single ordinary application or plugin principal SHALL span these capabilities.

## Fail-closed publication gates

The pathway remains `HITL-PENDING` and disabled until decisions define:

- exact pathway/service owner and canonical identifier spelling;
- publication eligibility and namespace stewardship;
- approval quorum, separation of duties, and emergency procedure;
- allowed DDL/data transformations and explicitly prohibited object types;
- handling of user-owned data, PII, licenses, and third-party content;
- trusted build, malware engines, sandbox, and retention requirements;
- identity allocation and collision handling;
- database predecessor, recovery point, forward-fix, and rollback policy;
- tier-specific promotion and production authorization; and
- revocation, recall, monitoring, incident response, and affected-device remediation.

Until all affecting gates close, every attempted Ace-to-ATAP transfer SHALL be denied,
including manually equivalent alternatives.
