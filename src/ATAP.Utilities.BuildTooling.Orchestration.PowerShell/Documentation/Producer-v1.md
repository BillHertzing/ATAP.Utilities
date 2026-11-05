# Producer, drain and recovery v1

The development source manifest and version.json report version 0.1.5. This is not the final shipping version or authority to release. Source/disposable fixture results do not mean installed or live-board acceptance.

## Actual entrypoints

- Submit-CoordRequest -EnvelopeBytes $bytes -HolderId $holder -SessionId $session queues one immutable authorized request. Pending means durable queue acceptance only.
- Invoke-CoordClerk -HolderId $coordinator -SessionId $session performs a bounded drain, recovering retained writes/operations before new batches.
- Export-CoordState -HolderId $coordinator -SessionId $session -DestinationPath $newPath writes a lossless protected export using CreateNew.
- Existing Get-CoordTask, Get-CoordResult, Get-CoordClaims and Stop-CoordClerk remain available. Query primitives retain their documented caller authorization requirements.

Invoke-CoordClerk's former unexported control-only Held stub has been replaced. The optional Control is the original same-process nine-key ReadOnlyDictionary used by Stop-CoordClerk: StatePath, ResourceId, LineageId, Generation, OwnerSessionId, InvocationId, ProcessId, StopSource and StartGate. The asynchronous start gate is single-use; the clerk never disposes borrowed cancellation. Without Control, normal bounded synchronous drains need only HolderId and SessionId.

## Configured custody and settings

The module reads the existing two-tier globals: configRootKeys[Name + ConfigRootKey] resolves the key in settings. It never guesses a root or creates a missing configured root. Required affected-operation settings:

- OrchestrationStateRootPath, OrchestrationCustodyRecordPath.
- OrchestrationMaxRequestBytes, OrchestrationMaxBatchBytes, OrchestrationMaxBatchRequests.
- OrchestrationMaxDrainRequests, OrchestrationMaxDrainBatches, OrchestrationMaxDrainMilliseconds.
- OrchestrationProtectedBackupRootPath for export.

Limits must be positive Int32/Int64 values. Fixture values are not measured production defaults. Millisecond limits are safe-boundary admission budgets, not preemptive deadlines.

State must be a direct file child of the configured state root. State root and witness must descend from actual CommonApplicationData. The witness is outside replaceable state. Each resource has its own protected witness directory; its resource.lock is held with FileShare.None throughout an operation. The existing configured CoordinatorBoard.lock is also held. All manual writers must honor the same handoff/lock contract; this is local cooperative exclusion, not distributed fencing.

Only the actual configured custodian Windows account operates this producer. Directories require protected DACLs. Owners and every mutating/security-changing Allow ACE must belong to the custodian SID, LocalSystem or Administrators. Files may inherit those rights from their verified protected direct parent; requiring an explicit protected flag on every atomic-replacement file would reject valid private inheritance. This checks actual ACLs, not an Approved=true request flag, and does not claim hostile-administrator isolation.

The ordinary-path check rejects links and junctions, including dangling links. Non-name-surrogate Windows cloud placeholders are accepted using the SAME fixed fsutil reparse tag mask as Read-CoordBoard: CLOUD 9000001A under FFFF0FFF, with name-surrogate bit20000000 absent. Native payload is not logged. This accommodates actual Dropbox metadata; it does not admit arbitrary reparse tags. New-CoordQuartetCandidate now uses that rule too.

## Protected record representation

The external JSON record has schemaVersion Coordination-custody-v1 and these bindings:

- admissionMode Established, custodianSid, resourceId, lineageId, generation, sprintId, coordinatorId.
- statePath and current stateSha256; pendingWrite is null outside an incomplete write.
- boardLockPath; scratchRoot is a fresh, not-yet-existing proper descendant of `C:/ProgramData/ATAP/AICoordinator/_generated` for the quartet candidate. The former D-only guard is superseded in the C1926 source change.
- actors: holderId, sessionId, windowsSid and role Coordinator or Worker.
- authorizations: reference, requestId, exact canonical digest, plus a unique assigned claimId for Claim.
- existingTasks: taskId and explicit transitive ancestorTaskIds. No ancestry is inferred from task-ID spelling.
- package: moduleVersion and files containing every installed non-test ps1/psm1/psd1/json relative path and lowercase SHA256 digest.

Chat IDs are cooperative role/correlation identifiers, never OS-authenticated identities. The Windows account, configured protected file and its registered roles/grants are the trust boundary. A request's authorizationReference alone grants nothing. The grant binds the entire canonical request digest. Workers cannot take claims or approve board changes; coordinator submissions can act for a registered holder.

The exact installed package file inventory can be constructed by enumerating those extensions under ModuleBase, excluding tests, and recording GetRelativePath and Get-FileHash. It must describe the accepted package, including schemas and the unchanged private/Read-CoordBoard.ps1 source consumed by the annotation seam.

## First use and consuming pilot — root only

1. Root resolves the release and runtime boundaries before a consuming pilot. C1927 is prepared, not ready: the module application mapping is absent, the pinned SprintLifecycle 0.1.61 renderer dependency closure is unverified, and the final version and release authority are unbound. Resolve the final NBGV version and approved release/install route before testing the exact package. Worker source evidence is not deployment.
2. The approved empty protected directories and configuration source establish the intended state root `C:/ProgramData/ATAP/AICoordinator/State` and custody record `C:/ProgramData/ATAP/AICoordinator/Custody/custody.json`; configuration source and IAC remain development work. These empty directories are not initialized state or a witness. With actual Bill approval for the concrete baseline and imports, establish the required protected backup and scratch paths, bind the current Windows SID, and obtain the manual board handoff while holding the existing coordinator lock.
3. Before initial state creation, durably consume the unique FIRST_USE/bootstrap ID in the protected witness as Establishing. Preserve it on interruption. An absent directory or missing state never authorizes re-bootstrap.
4. Establish the accepted state-v1 baseline with exact quartet digests, registered roots, imported claims/reservations and immutable lineage/epoch. Bind package files and actor/grant registry. Publish Established only after validating the state and its exact stateSha256. No module public command silently performs these setup steps.
5. Register each exact pilot request digest in authorizations under the witness lease. Run Claim, ReportResult, an explicit annotation AcceptChange, then Release for an existing task. Each request binds the observed current revision and Applied predecessors. The public calls above are the actual consuming commands.
6. Export to a fresh protected backup file. Verify lossless bytes and retained results in a separately authorized clean restore with no live writer. Do not close installed/pilot leaves on source tests alone.

## Mutation and recovery

Submission starts queue ordinals at string0, uses checked signed-Int64 capacity and refuses overflow. Same-ID/same-content retry returns original retained status without another ordinal or effect; changed content is IdentityConflict.

State writes first retain the exact proposed image in the protected external pendingWrite journal, then atomically replace/flush/read back state and advance the witness watermark. Prepare/Complete phases instead retain their exact immutable plan/operation identity before calling the existing Save-CoordOperation/Complete-CoordOperation seams. A later authorized clerk resumes that SAME work; third-state outputs hold recovery. No directory-loss reset, renumbering, identity reuse, delete cleanup or implicit retry is added.

Independent eligible requests share a base head and are selected by durable ordinal with explicit task/scope/reservation conflicts. Causal chains wait for already Applied predecessors. Claim/release use Update-CoordClaim; report validates its owned claim and actual file SHA256 evidence. AcceptChange currently supports the EXISTING annotation-only New-CoordBoardChange contract, not arbitrary checkbox/status/completion edits. Multiple annotation previews compose before one installed SprintLifecycle0.1.61 candidate render; unchanged quartet batches render zero times. Existing Save/Complete retain immutable prepared plans and receipts.

Exports contain exact state/custody byte images plus all observed quartet bytes, including pending/prepared/recovery history. Export is not restore approval. An incomplete protected write or prepared operation cannot be reported as a drained queue, even if cancellation arrives after a state receipt.

## Verification

C1926 verified only the source scratch guard: 15 passed and 35 were not run in an isolated ProgramData snapshot with synthetic file and renderer mocks. It did not exercise the real renderer, a live board or an installed module. Other historical fixtures still refer to repository or D-based locations; they have not all been migrated, and the full suite has not been proved compatible with the current root boundary.

Required producer-runtime I/O must remain under the approved `C:/ProgramData/ATAP/AICoordinator` root. The release and consuming-runtime closure, including launcher/profile behavior, package dependencies and test paths, remains to be reviewed and authorized. Do not infer a permitted profile or execution exception from the C1926 synthetic evidence.

## Established witness updates

Update-CoordWitness -HolderId <coordinator> -SessionId <session> -ExpectedWitnessBytes <before> -ProposedWitnessBytes <after> -UpdateId <guid> -ApprovalReference <reference> appends exactly one actor OR one exact-request authorization. Root must independently verify approval of the exact delta; the reference is audit correlation only. Existing custodian/coordinator admission and both locks are reused, and HolderId must equal coordinatorId. This does not transfer the active writer, establish custody or bootstrap missing state.

All prior entries/order and every other raw JSON subtree (including unknown top-level fields) are frozen. Number lexemes, string escapes and nested whitespace must match literally; top-level property order is also fixed. Actors/grants are closed objects; duplicate holder/session identities, reused reference or request ID, role/SID edits, removals, multi-appends and no-ops refuse. Digests are exact lowercase SHA256; claimId, when supplied, is nonempty. IDs and grants are supplied, never invented. Later request admission still validates the canonical digest and request category.

The resource must be Admitted and idle: pendingWrite must be exactly null; no Pending/Prepared/NeedsRecovery requests or Prepared/NeedsRecovery operations may exist. Historical terminal entries remain unchanged. Supply the next grant only after earlier work has settled. State bytes, watermark, package, paths, lineage, generation and existing journals are untouched.

The command retains CreateNew/flush/readback exact before/after images and an intent beside the protected witness, named custody.json.update-<GUID>.before.bin, .after.bin and .intent.json. It reuses Write-CoordAtomicBytes and checks exact witness readback, protection and unchanged state before retaining a .receipt.json and returning Updated. Files inherit the protected parent; this command never edits ACLs or creates roots. WhatIf performs no admission/file I/O and reports only ProposedOnly, not validated authority.

Failures before entering the atomic writer do not request witness replacement. The existing writer exposes no failure phase, so EVERY error after entering it is conservatively WitnessUpdateOutcomeUncertain, even a possible stage or snapshot failure. The approved change may already exist after an exception. Preserve sidecars/stages, stop cooperative work, and reconcile exact before/after/third-state under separately authorized custody; do not retry, restore or delete evidence automatically. No new durable consumer-hold marker or cross-file/power-loss guarantee is added.

Land and review this command before final release packaging. The new public export, manifest and built module change the final signed installed inventory. This append API cannot update package pins; existing-resource upgrades still require a separate approved compatibility/re-admission procedure. Source tests do not establish installed consumption, FIRST_USE, operational authority or pilot acceptance.
