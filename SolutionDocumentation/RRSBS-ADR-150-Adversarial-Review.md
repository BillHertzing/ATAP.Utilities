# RRSBS ADR-150: Adversarial Review of Wave 1 Contracts

Status: Review complete — **reject for HITL progression pending remediation**  
Date: 2026-08-02  
Owner: RDB-150 / Task 14.20.b.13

## Review boundary

This is an adversarial document review, not human approval. It reviews the
twelve drafted Wave 1 ADRs against the original RDB-150 scenario list and the
Analysis hidden-assumption list. A `Pass` means the cited ADRs state a
testable contract; it does not mean that SQL, consumers, package delivery,
execution, or live deployment has been implemented or proven.

The review recommends that Wave 1 not proceed to its HITL gate until each
`Fail` is accepted, remediated, or explicitly deferred by the coordinator and
HITL. No reviewed ADR was changed by this review.

## Reviewed ADR set

- [ADR-100: Glossary and Entity-Philote Authority](RRSBS-ADR-100-Glossary-and-Entity-Philote-Authority.md)
- [ADR-105: Entity-Reference Contract](RRSBS-ADR-105-Entity-Reference-Contract.md)
- [ADR-110: Temporal Versioning](RRSBS-ADR-110-Temporal-Versioning.md)
- [ADR-115: RollItUp Publication and Concurrency](RRSBS-ADR-115-RollItUp-Publication-and-Concurrency.md)
- [ADR-125: External Consumer Boundary](RRSBS-ADR-125-External-Consumer-Boundary.md)
- [ADR-130: Typed Values, Bindings, and Secret References](RRSBS-ADR-130-Typed-Values-Bindings-and-Secret-References.md)
- [ADR-140: Manifestation and Executor Safety](RRSBS-ADR-140-Manifestation-Executor-Safety.md)
- [ADR-145: Execution Reliability](RRSBS-ADR-145-Execution-Reliability.md)
- [ADR-146: Plan Approval](RRSBS-ADR-146-Plan-Approval.md)
- [ADR-147: SourceArtifact and Path Identity](RRSBS-ADR-147-SourceArtifact-and-Path-Identity.md)
- [ADR-148: Package and Compatibility](RRSBS-ADR-148-Package-and-Compatibility.md)
- [ADR-149: Retention, Privacy, and Backup](RRSBS-ADR-149-Retention-Privacy-and-Backup.md)

## RDB-150 scenario results

| Scenario | Outcome | Evidence | Required remediation |
| --- | --- | --- | --- |
| Repeated Rule occurrence | **Fail** | ADR-115 validates a RuleVersion tree but does not define the repeatable BuildSet/RuleSet occurrence key. | RDB-230/RDB-240 must define occurrence identity and composite constraints. |
| Diamond graph | Pass | ADR-115 topology requires one parent per non-root and rejects shared-node diamonds. | Prove with RDB-280 invalid rows. |
| Cyclic graph | Pass | ADR-115 requires acyclicity before publication. | Prove with RDB-280 and RDB-610 fixtures. |
| Missing, extra, or wrong-type input | Pass | ADR-115 requires exact input resolution; ADR-130 defines typed value/binding validation. | Prove with RDB-220/RDB-610 fixtures. |
| Stale default | Pass | ADR-130 snapshots effective defaults and explicitly rejects later default mutation of a published version. | Prove with RDB-240/RDB-610 fixtures. |
| Concurrent edit | Pass | ADR-115 requires expected revision and serializable/key-range publication locking. | Prove collision behavior in RDB-610. |
| Unauthorized fork, edit, or run | Pass | ADR-105 separates permission from tags; ADR-146 requires immutable authorization for plans. | RDB-240/RDB-250 must enforce the complete verb set. |
| Path traversal or case collision | Pass | ADR-140/147 reject traversal, aliases, and ordinal-case collisions. | Prove under RDB-630 temporary-root tests. |
| Same plan run twice | Pass | ADR-145 defines operation fingerprint/idempotency and retry linkage. | Prove RDB-820 crash/retry cases. |
| Partial failure and retry | Pass | ADR-145 defines journal/outbox, reconciliation, and recovery-required behavior. | Prove RDB-820 without a live target. |
| One output produced by multiple steps | Pass | ADR-140 permits zero-or-one observed artifact per attempt/output slot and requires one producing execution. | RDB-250 must name the unique constraint and decide contributor representation. |
| Content hash drift | Pass | ADR-147 separates normalized SHA-256 drift identity from exact-byte hash proof. | Prove with RDB-460/RDB-470 fixtures. |
| Projection rebuild | **Fail** | ADR-110 says projections may regenerate, but no Wave 1 ADR defines watermark, staleness, failure, consumer cutover, or blue/green semantics. | RDB-640/RDB-650 must supply a projection contract before consumer cutover. |
| Attribution dispute | **Fail** | ADR-105 distinguishes attribution from permission, but no contract defines correction/dispute lineage, retention, or authoritative resolution. | RDB-200 plus RDB-149/HITL must define correction and retention policy. |
| Future-dated business fact | **Fail** | ADR-110 distinguishes UTC system time from business-effective time, but does not specify which fact classes permit future dating or the validation/approval rule. | RDB-110 follow-up or RDB-200 must define fact-type admissibility and negative fixtures. |

Result: 11 pass, 4 fail. The four failures are blocking conceptual gaps, not
implementation defects that can be accepted as covered by later code alone.

## Hidden-assumption dispositions

`Approve` below means the assumption is sufficiently constrained by an ADR for
later design work. `Reject` means it remains unproven, conflicts with the
approved scope, or requires an explicit later decision; it is not a rejection
of the corresponding future task.

| # | Hidden assumption | Disposition | Review rationale and owner |
| --- | --- | --- | --- |
| 1 | Current data can be deterministically mapped. | Reject | RDB-160/RDB-170 conversion evidence is future work. |
| 2 | Philotes can be reused without semantic collision. | Reject | RDB-010F/RDB-160 must prove collision-free disposition. |
| 3 | Rule and RuleVersion each bind exactly one kind/version. | Approve | ADR-115 requires kind compatibility; RDB-210/220 must implement FKs. |
| 4 | A Primitive belongs to one RuleKind for life. | Approve | ADR-100 separates RuleKind meaning; RDB-210 must make it enforceable. |
| 5 | Rule graphs are trees, not DAGs. | Approve | ADR-115 rejects multiple parents and cycles. |
| 6 | Membership is ordered and permits repeated child versions. | Reject | No ADR specifies the RDB-230 occurrence/membership key. |
| 7 | Occurrence identity is deterministic. | Reject | RDB-240 has not yet supplied the composite identity contract. |
| 8 | Defaults are frozen at publication. | Approve | ADR-130 snapshots effective defaults. |
| 9 | Published versions avoid mutable grammar/executor aliases. | Approve | ADR-140 requires executor/grammar/environment hashes. |
| 10 | A plan has one immutable target scope. | Approve | ADR-146 binds plan, target, policy, and hash. |
| 11 | Directory/external actions differ from byte artifacts. | Approve | ADR-140 distinguishes planned slots and observed artifacts. |
| 12 | Same-database FKs are available for drawn ownership edges. | Reject | ADR-125 deliberately avoids depending on undecided AceCommander topology. |
| 13 | Experimental is disposable or facts have a migration path. | Reject | RDB-160/170 and reset evidence remain required. |
| 14 | Breaking baseline can be coordinated with every consumer. | Reject | RDB-148 is contract-only; RDB-835 cutover evidence is future work. |
| 15 | Old immutable packages remain available. | Reject | RDB-148 requires it but RDB-550 must prove feed resolution. |
| 16 | BuildMaster/ReleaseBundle work is authorized/in sprint. | Reject | Requires PKG-AUTH-01 and infrastructure delivery, not an ADR assertion. |
| 17 | Each new RuleKind is executable or metadata-only. | Approve | ADR-140 default-deny executor boundary supports the decision; RDB-185 classifies kinds. |
| 18 | AI-directed output is distinct from byte reproducible output. | Approve | ADR-140 separates environment/hash proof from non-deterministic execution class. |
| 19 | Time uses UTC precision and avoids clock-skew ordering. | Approve | ADR-110/146 require UTC timestamps and recorded ordering inputs. |
| 20 | Philote audit avoids mutable personal/legal identity. | Approve | ADR-100/130/149 separate identity, SecretName, and privacy boundaries. |
| 21 | Attribution/licensing supports dispute correction and retention. | Reject | Scenario failure: no correction/retention contract exists. |
| 22 | Tags never grant permission. | Approve | ADR-100/105/125 explicitly prohibit it. |
| 23 | Projections tolerate rebuild or use blue/green semantics. | Reject | Scenario failure: no watermark/staleness/cutover contract exists. |
| 24 | Source identity survives renames and worktrees. | Approve | ADR-147 specifies Repository identity, lineage, and retirement. |
| 25 | Baseline obeys selected Flyway transaction/batch rules. | Reject | RDB-300/RDB-480 must prove actual SQL Server/Flyway behavior. |

Result: 13 approved for conceptual continuation, 12 rejected/deferred pending
named future evidence or a new decision.

## Cross-ADR findings

1. ADR-115's mutable current-publication projection must be reconciled with
   ADR-110's temporal model before RDB-400 SQL, as both claim lifecycle
   authority over currentness.
2. ADR-140's one-producing-execution rule needs an explicit RDB-250 decision
   for contributor relationships; the current wording rejects multiple
   producers but does not model legitimate contributions.
3. ADR-147 provides SourceArtifact lineage, but neither ADR-147 nor ADR-149
   gives attribution disputes an equivalent immutable correction lineage.
4. The twelve ADRs are normative inputs only. None substitutes for the Wave 2
   conversion gate, Wave 3 relational counterexamples, or Wave 5 SQL proof.

## Required disposition

The review disposition is **reject for HITL progression pending remediation**.
This is not a human approval or rejection of Wave 1. The coordinator must
obtain explicit HITL disposition for the four failed scenarios, the fifteen
rejected assumptions, and the cross-ADR findings before opening logical DDL.
