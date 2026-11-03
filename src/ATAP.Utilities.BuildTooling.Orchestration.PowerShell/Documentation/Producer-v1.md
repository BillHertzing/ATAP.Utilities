# Producer, drain and recovery v1

Module source version: 0.1.4. Source/disposable fixture results do not mean installed or live-board acceptance.

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
- boardLockPath; scratchRoot is an existing D:/ATAPArtifacts descendant for the existing quartet candidate.
- actors: holderId, sessionId, windowsSid and role Coordinator or Worker.
- authorizations: reference, requestId, exact canonical digest, plus a unique assigned claimId for Claim.
- existingTasks: taskId and explicit transitive ancestorTaskIds. No ancestry is inferred from task-ID spelling.
- package: moduleVersion and files containing every installed non-test ps1/psm1/psd1/json relative path and lowercase SHA256 digest.

Chat IDs are cooperative role/correlation identifiers, never OS-authenticated identities. The Windows account, configured protected file and its registered roles/grants are the trust boundary. A request's authorizationReference alone grants nothing. The grant binds the entire canonical request digest. Workers cannot take claims or approve board changes; coordinator submissions can act for a registered holder.

The exact installed package file inventory can be constructed by enumerating those extensions under ModuleBase, excluding tests, and recording GetRelativePath and Get-FileHash. It must describe the accepted package, including schemas and the unchanged private/Read-CoordBoard.ps1 source consumed by the annotation seam.

## First use and consuming pilot — root only

1. Root uses the normal BuildMaster module release workflow for this exact module/version; no direct feed publication. Resolve the final NBGV version after the release commit, test/install that exact package, and import it in a fresh profiled shell. Worker source evidence is not deployment.
2. With actual Bill approval for the concrete ProgramData paths/baseline/imports, create protected state, witness and backup directories, the selected scratch root, and bind the current Windows SID. Obtain the manual board handoff while holding the existing coordinator lock.
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

Run the focused Manifest, Invoke-CoordClerk and CoordProducer tests with Pester6.2.0 in a profiled shell. Disposable custody uses a substituted ProgramData location under repository _generated, actual Windows identity/ACL/leases and real persistence. Annotation scratch uses the already-selected D-only candidate path. No actual ProgramData, live planning board or installed module is changed by these fixtures.
