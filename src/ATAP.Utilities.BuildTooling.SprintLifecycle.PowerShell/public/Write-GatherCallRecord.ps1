# Load contract: dot-sourcing this file defines Write-GatherCallRecord and does nothing
# else. There is no top-level executable code, no module-scope constant, and no alias —
# every constant this function needs (the record version, the digest algorithm, the
# canonical key order) is computed or declared inside the function body, so importing the
# module never touches the filesystem.
function Write-GatherCallRecord {
  <#
  .SYNOPSIS
    Appends exactly one gather-call record to the append-only record store — by default
    the DURABLE store under the `_Planning` sprint worktree — concurrency-safely, for a
    single `gather-content-summary` invocation.

  .DESCRIPTION
    Implements `gather-call-record.contract.v1` (recordVersion 1.0.0) for Task 15.183.B01.
    One record is written per invocation, without exception — including stubbed calls,
    failed calls, and calls that returned nothing — so that a worker which skipped the
    mandatory gather step and a worker whose call returned nothing never produce the same
    on-disk evidence.

    STORAGE FORM — one immutable file per record
    --------------------------------------------
    Each record is written as a JSON Lines file containing exactly one line: the record,
    minified, UTF-8 without BOM, terminated by a single `\n`. The file name is

        <yyyyMMddTHHmmssfff>Z-<invocationId>.jsonl

    beneath the store directory chosen by `-StoreTarget` (see WHERE RECORDS GO below).

    WHERE RECORDS GO — a switchable decision, not a constant
    -------------------------------------------------------
    `-StoreTarget Durable` (the DEFAULT) writes beneath the `_Planning` sprint worktree:

        <_Planning sprint worktree>/InformationForTheFuture/Sprint<NNNN>/<Stream>/<TaskFolder>/gather-calls/

    `-StoreTarget Generated` writes the layout contract § 6.2 proposes, beneath the
    CALLING worktree:

        <WorktreeRoot>/_generated/Sprint<NNNN>/<Stream>/gather-calls/

    Durable is the default because Task 15.183 was rescoped on 2026-08-26: the
    handoff-correlation half was parked, and these records are no longer point-in-time
    verification evidence. They are seed data for the Tags database and the initial
    prompt-to-tag associations — information for the FUTURE, and therefore R-38 material.
    `_generated/` beneath an ephemeral sprint worktree is git-ignored and deleted at
    sprint end, so a record written there would not survive the sprint that produced it.
    That was the bug. Contract § 6.2 still shows the `_generated` layout, but it is headed
    "File layout (proposed)" and its rationale — "this is point-in-time evidence" — is the
    premise the rescope overturned; § 6.2 also defers the durable artifact to
    `correlated-corpus.contract.v1.md`, which is precisely the half that got parked.

    OPERATOR INTENT, recorded here on purpose: durable is the target FOR NOW. The records
    move back under `_generated` once the bugs are worked out. That is why the target is a
    documented parameter with a default rather than a constant buried in the resolver —
    reversing it is one argument, not a code change, and neither path is hardcoded at a
    call site. Both are composed from resolved sprint context by
    `Resolve-GatherCallStoreDirectory`.

    WHICH ROOT IS "THE" ROOT — two different jobs, kept distinct
    ------------------------------------------------------------
    Since the durable store lives under a DIFFERENT worktree than the caller's, "the
    worktree root" now means two things, and conflating them would be a silent corruption:

      * The record BODY's `worktreePath` and `repositoryName` always describe the CALLING
        worktree — the one the gather call actually ran in. These did not change.
      * The write DESTINATION is derived from the `_Planning` sprint worktree, found from
        the calling root's PARENT (the Git root holding every worktree side by side) and
        the resolved sprint number.

    Only the destination moved. A consumer reading a record still learns which repository
    the call came from, even though the file no longer sits in that repository.

    A directory of single-line `.jsonl` files is the maximal application of the sharding
    refinement in contract § 6.2 ("a recorder MAY shard ... the harvester MUST treat all
    `*.jsonl` files under `gather-calls/` as one logical stream"). It satisfies § 6.1
    byte-for-byte — the concatenation of the files, in any order, is a valid JSONL stream —
    while making append-only-ness and concurrency-safety structural rather than
    disciplinary: no writer ever opens a file another writer could be writing, so there is
    nothing to lock and nothing to corrupt.

    CONCURRENCY SAFETY — what actually guarantees it
    ------------------------------------------------
    Three independent properties, each defeating a specific failure:

      1. Never overwrite. The record is staged into `_partial-<guid>.tmp` in the target
         directory and published with `[System.IO.File]::Move`, whose two-argument
         overload REFUSES to overwrite an existing destination. Two writers that somehow
         produced the same file name do not silently clobber one another; the second gets
         an explicit failure. Publication is therefore create-only, which is the same
         mutual exclusion the agent-authored half relies on.
      2. Never tear. The full line is serialized in memory, written to the staging file in
         one `Write`, and forced to stable storage with `Flush($true)` (FlushFileBuffers)
         BEFORE the name is published. A reader globbing `*.jsonl` can therefore never
         observe a partially written record: a half-written file still has a `.tmp` name
         and is invisible to that glob. This matters concretely — a 22-NUL-byte torn write
         has been observed on this workstation, so the metadata-extended-but-data-unflushed
         failure is not hypothetical. The residue of a crash here is an orphan `.tmp` file,
         which is inert.
      3. Never double-count. `invocationId` is minted once per call and appears in both the
         file name and the record body, so a retry is a new file and a repeated write of
         the SAME id is a name collision that fails loudly (rule 1) instead of appending a
         duplicate. Per contract § 7.2 duplicate ids are malformed, never deduplicated.

    THE TWO HALVES — and why a reader cannot tell them apart
    -------------------------------------------------------
    The canonical `gather-content-summary` agent has NO terminal: its toolset is
    read-file, list-directory, search-text, edit-file, create-file, and
    dispatch-subagent-restricted. It cannot call this function. It therefore authors its
    own record file directly with create-file, following the obligation written into
    `.ai/agents/gather-content-summary.agent.md`.

    This function is the format's source of truth and is designed so that a directory
    written by that agent is EXACTLY what this function would have produced. Same
    directory, same file-name grammar, same key set, same key order, same minification,
    same encoding, same terminator. `_partial-*.tmp` staging is an implementation detail
    of this half that is deleted-by-rename before any reader can see it. Consequently a
    consumer reading the store cannot determine which half wrote a given record, and must
    not try — the record's `agentName` says who called, never who serialized.

    KEY ORDER is part of the format, not an accident: keys are sorted ordinally (UTF-16
    code unit, `StringComparer.Ordinal`), which is what makes the line reproducible by a
    half that has no serializer. The same ordering rule is applied recursively, which makes
    it RFC 8785 JCS key ordering, which is what the response digest is defined over.

    INVOCATION ID
    -------------
    A UUIDv4, lowercase, hyphenated, 36 characters, minted by the recorder at issue time
    and never content-derived (contract § 3.1.1). "The same logical call" means one
    issuance of `gather-content-summary`: the id is minted once, before the response
    returns, and every later reference to that call — the file name, the record body, the
    handoff, a superseding record — uses that same value. A retry is by definition a
    DIFFERENT logical call and mints a new id, linking back through
    `retryOfInvocationId`; collapsing a retry onto the prior id would erase the fact that
    two calls happened.

    This choice is also what makes the format implementable by the terminal-less half. A
    content-derived id (a hash of prompt and tags) would be uncomputable by an agent with
    no hashing tool, so it would be a broken design for half (B) even if the contract
    permitted it. A UUIDv4 needs only 32 random hex digits with the version and variant
    nibbles pinned, which both halves can produce.

    WHAT IS NEVER RECORDED
    ----------------------
    The full `items[]` response content is never persisted — only `itemCount`,
    `responseStatus`, and a `responseDigest` whose algorithm is named explicitly:
    SHA-256, lowercase base16, computed over the RFC 8785 JCS form of the `items` array
    only. When `items` is `[]` the digest is the known constant
    `4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945`, which makes
    "returned nothing" a positively checkable fact rather than an absence. Stubbed-empty
    and genuinely-empty share that digest by design and are distinguished by `stubMarker`
    and `responseStatus`, never by the digest.

    Secrets, credentials, connection strings, tokens, private keys, and unrelated
    conversation text are never recorded. `Prompt`, `ErrorMessage`, and the raw tags pass
    through pattern-based redaction (contract § 5) before serialization, and the digest is
    computed after redaction. SecretNames are permitted; secret VALUES are not. Redaction
    is visible — a detected value becomes the literal `[REDACTED:<kind>]`, never a silent
    deletion — and `redacted`/`redactionCount` let a consumer filter without re-scanning
    text. Detection is deliberately biased toward over-redaction: a false redaction costs
    one unreadable fragment, a false pass writes a secret into a durable artifact.

    Paths are repository-relative wherever a repository-relative identity suffices.
    `worktreePath` is the one deliberate exception and is absolute, because its entire job
    is to say WHICH repository root a record came from and it therefore cannot be relative
    to one (contract § 3.2).

    ABSENCE
    -------
    `null` in a record means "the recorder looked and it was not available". It never means
    "the recorder did not look", and it is never replaced by a guess, a placeholder such as
    `"unknown"`, or a value inferred from a sibling field. `conversationId` and
    `conversationTitle` in particular are recorded only when supplied by the caller from
    the harness; an invented conversation title is indistinguishable from a real one
    downstream, which would poison the whole corpus.

  .PARAMETER Tags
    The tags exactly as submitted to `gather-content-summary`, in submission order and
    original casing. Required and non-empty — an empty tag list is an argument error at
    the agent, not an empty result — and an empty list is a terminating argument
    exception here, distinct from the non-terminating write failures below. Recorded
    verbatim (post-redaction) as `tagsRaw`, and additionally as `tags`: trimmed,
    invariant-lowercased, internal whitespace runs collapsed to `-`, empties dropped,
    de-duplicated first-occurrence-wins, ordinal-sorted.

  .PARAMETER AgentName
    The canonical name of the agent that issued the gather call, e.g.
    `junior-dev-coder-sh`. Free string, not an enum: real callers include coordinator and
    ad-hoc names that an enum would reject. Required — a call always has a caller.

  .PARAMETER Depth
    The `Depth` argument as submitted. Defaults to the agent's own default of 3.

  .PARAMETER Width
    The `Width` argument as submitted. Defaults to the agent's own default of 2.

  .PARAMETER Instance
    The `Instance` argument as submitted, e.g. `production`.

  .PARAMETER Prompt
    The prompt text submitted with the call, recorded in full after redaction. Stored
    whole rather than truncated because it is short caller-authored input and truncating
    it would destroy the ability to audit what was asked.

  .PARAMETER Response
    The response envelope returned by `gather-content-summary`, as a PSCustomObject, a
    hashtable, or a JSON string. `outcome`, `responseStatus`, `stubMarker`,
    `stubBlockedBy`, `itemCount`, `truncated`, `errorMessage`, and `responseDigest` are
    all derived from it mechanically per contract § 3.4 — none of them are judgement
    calls, and none of them may be passed in.

  .PARAMETER NoResponse
    Declares that no envelope was received at all, because the call threw or never
    returned. Produces `outcome: "failure"`, `responseStatus: null`, `itemCount: null`,
    `truncated: null`, and `responseDigest: null`, with `-ErrorMessage` carrying the
    redacted exception text. Mutually exclusive with `-Response`.

  .PARAMETER ErrorMessage
    The envelope's `error`, or the exception message when `-NoResponse` is used. Redacted
    before it is written.

  .PARAMETER RequestResponsePairId
    The host harness's identifier for the request/response turn. Omit it when the harness
    exposes none: it is then recorded as `null`, never as a synthesized value, never as
    the `invocationId` copied across, never as an empty string.

  .PARAMETER Ordinal
    1-based counter of gather calls within the scope of `SessionId`, in issue order.
    Prefer supplying it: the caller knows how many calls it has issued, whereas the
    fallback derivation counts existing records in the store and is therefore racy under
    concurrent calls inside one session. When `SessionId` is null the ordinal is scoped to
    the record file, which in this one-record-per-file layout is always 1.

  .PARAMETER AgentModel
    The per-call model override actually used, or omitted when the variant's default model
    was used, in which case it records as `null`.

  .PARAMETER SessionId
    The harness session id, when exposed. Determines `ordinalScope`: `session` when
    present, `file` when absent.

  .PARAMETER TaskId
    The board task this call was made in service of, e.g. `15.183.B01`. Omitted for a
    caller not working a board task.

  .PARAMETER WorktreeRoot
    Absolute path of the worktree root the caller is running in. REQUIRED IN EFFECT: an
    omitted, blank, or unresolvable value is a TERMINATING error. The recorder does not
    walk up from the current location to the nearest `.git` ancestor, and there is no
    switch to re-enable that — the C00 gate ratified fail-closed here.

    Two independent reasons, both pointing the same way. An inferred root is
    indistinguishable downstream from a stated one, which would poison `worktreePath`, the
    one field whose whole job is to say which repository a call came from. And since the
    durable store is located from this root's PARENT, a guessed root would write a
    sprint's seed data under whatever repository the shell happened to be sitting in.

    Recorded as `worktreePath` with forward slashes and no trailing slash. This is the
    CALLING worktree and stays so under `-StoreTarget Durable`, where the file itself
    lands under `_Planning`.

  .PARAMETER StoreTarget
    Which store layout to write. `Durable` (default) writes under the `_Planning` sprint
    worktree so records merge to stable at sprint end; `Generated` writes the contract
    § 6.2 layout under the calling worktree's `_generated` tree. See WHERE RECORDS GO —
    this is the switch that reverses the decision when the records move back.

  .PARAMETER TaskFolder
    Task folder segment beneath the stream folder in the DURABLE layout only. Defaults to
    `Task15.183`, matching the folder that already holds this record type's contract.

  .PARAMETER PlanningRoot
    The `_Planning` sprint worktree to write the durable store into. Supplying it skips
    discovery, which is how a test points the writer at a fixture without a real
    `_Planning` worktree. When omitted it is discovered beneath `-GitRoot` by the sprint
    worktree folder grammar, pinned to the resolved sprint number.

  .PARAMETER GitRoot
    The directory holding every repository and sprint worktree side by side. Defaults to
    the parent of `-WorktreeRoot`, which is a derivation from a stated value rather than
    an inference from ambient state. Used only to discover `-PlanningRoot`.

  .PARAMETER RepositoryName
    The stable repository name with any `-wt-*` sprint suffix stripped. When omitted it is
    derived from the worktree directory name, which is deterministic; if that derivation
    is not possible it records as `null` rather than guessing.

  .PARAMETER ConversationId
    The harness conversation id, when exposed. Never invented.

  .PARAMETER ConversationTitle
    The harness conversation title, when exposed. Never invented. Independent of
    `ConversationId`: recording an id with a null title is correct and expected.

  .PARAMETER RetryOfInvocationId
    The `invocationId` of the attempt this call retries. A retry is a new call with a new
    id, never an amendment to the old record.

  .PARAMETER SupersedesInvocationId
    The `invocationId` of a record this one corrects. Both records remain in the stream;
    the superseded one is never edited or removed.

  .PARAMETER SprintNumber
    Four-digit sprint number used to build the default store path. When omitted it is
    parsed from the worktree path pattern `-Sprint-NNNN-work-items`.

  .PARAMETER Stream
    Stream folder segment under the sprint folder. Defaults to `StreamM`.

  .PARAMETER StoreRoot
    The `gather-calls` directory itself. Supplying it bypasses sprint, planning, and
    store-target resolution entirely, which is how a test points the writer at a temporary
    directory. It does NOT bypass `-WorktreeRoot`, which is still required because it
    feeds the record body rather than the path. Aliases: `RecordRoot`, `GatherCallsRoot`,
    `Path`.

  .PARAMETER PassThruLine
    Include the serialized JSON line on the returned object. Off by default so that a
    caller cannot accidentally echo a prompt into a transcript.

  .OUTPUTS
    [PSCustomObject] with fields:
      Ok              [bool]          — the record was written, or would have been under -WhatIf
      Written         [bool]          — a file actually landed on disk ($false under -WhatIf)
      RecordPath      [string]        — absolute path of the record file written, or that
                                        would have been written
      RecordDirectory [string]        — the store directory
      InvocationId    [string]        — the id minted for this call. Returned rather than
                                        accepted: there is no -InvocationId parameter, so
                                        read it from here if you need to reference the call
      Ordinal         [int]
      OrdinalScope    [string]        — 'session' or 'file'
      TimestampUtc    [string]        — issue time, ISO-8601 UTC, millisecond precision
      Outcome         [string]        — success | partial | failure | stubbed
      RecordVersion   [string]        — '1.0.0'
      Redacted        [bool]
      RedactionCount  [int]           — -1 signals redaction unavailable, content withheld
      Record          [PSCustomObject] — the record as an object
      Line            [string]        — the serialized line, only with -PassThruLine
      Error           [string]        — null on success; the write failure otherwise

    Every example below binds `-WorktreeRoot` explicitly. That is not incidental style: an
    omitted root is a terminating error (see `.PARAMETER WorktreeRoot`), so an example that
    left it out would teach the failure mode. All example values are synthetic.

  .EXAMPLE
    $envelope = Get-Content ./response.json -Raw
    Write-GatherCallRecord -Tags @('handoff','schema') -AgentName 'junior-dev-coder-sh' `
      -WorktreeRoot 'C:/GitHub/ExampleRepo-wt-1-Sprint-0015-work-items' `
      -TaskId '15.183.B01' -Prompt 'Context for the recorder unit' -Response $envelope

    Writes one record for a completed call. Because retrieval is stubbed the envelope
    carries a `stub` key, so `outcome` is `stubbed` — a first-class outcome, not a failure.

  .EXAMPLE
    try { $envelope = ... } catch {
      Write-GatherCallRecord -Tags @('handoff') -AgentName 'junior-dev-coder-jm' `
        -WorktreeRoot 'C:/GitHub/ExampleRepo-wt-1-Sprint-0015-work-items' `
        -NoResponse -ErrorMessage $_.Exception.Message
    }

    The failure case the recorder exists to catch: a call that never returned an envelope
    is still recorded, with outcome 'failure' and the redacted exception message.

  .EXAMPLE
    Write-GatherCallRecord -Tags @('drift') -AgentName 'junior-dev-coder-jl' `
      -WorktreeRoot $root -StoreRoot (Join-Path $TestDrive 'gather-calls') -WhatIf

    Computes the record and the destination path, returns the object, and writes nothing.
    `-WorktreeRoot` is supplied even though `-StoreRoot` fixes the path, because it is the
    record's `worktreePath`, not a way of finding the directory.

  .EXAMPLE
    Write-GatherCallRecord -Tags @('drift') -AgentName 'x' -WorktreeRoot $root `
      -StoreTarget 'Generated'

    Writes the legacy contract § 6.2 layout under the calling worktree's `_generated`
    tree. This is the one argument that reverses the durable default when the records
    move back.

  .EXAMPLE
    $r = Write-GatherCallRecord -Tags @('drift') -AgentName 'x' -WorktreeRoot $root -StoreRoot $dir
    if (-not $r.Ok) { Write-PSFMessage -Level Error -Message $r.Error }

    The non-blocking failure contract: a recorder failure must never fail the gather call
    or the worker, so the failure is returned rather than thrown.

  .NOTES
    Task 15.183.B02 (Sprint 0015, Stream M), amending Task 15.183.B01. Implements
    `gather-call-record.contract.v1.md` recordVersion 1.0.0.

    B02 changed three things and deliberately changed nothing else:
      1. The default write target moved from `_generated` to the durable `_Planning`
         store, because the rescope made these records information for the future rather
         than point-in-time evidence (R-38). `-StoreTarget` switches it back.
      2. An unbound `-WorktreeRoot` now fails closed instead of walking up to the nearest
         `.git` ancestor.
      3. The five nested helpers moved to `private/`, one function per file, joined by
         `Resolve-GatherCallStoreDirectory`.

    The record FORMAT is untouched: same field set, same ordinal key order, same
    minification, encoding, terminator, and file-name grammar. The agent-authored half in
    `.ai/agents/gather-content-summary.agent.md` still produces byte-format-identical
    records. KNOWN DIVERGENCE, reported rather than worked around: that agent file writes
    to the `_generated` location and is outside this unit's writable scope, so until it is
    updated the two halves agree on format but not on directory.

    ERRORS AND WARNINGS — how failure surfaces:
      * Argument faults are TERMINATING. An empty `Tags`, a malformed `TaskId`, a
        non-positive `Depth`/`Width`, or `-Response` together with `-NoResponse` throw.
        These are caller bugs that would otherwise produce a malformed record, and a
        malformed record is worse than a loud stop.
      * Write faults are NON-TERMINATING and explicit, never silent. The function writes a
        `Write-PSFMessage -Level Error`, emits a non-terminating error on the error stream,
        and returns an object with `Ok = $false` and `Error` set. The caller therefore sees
        the failure three ways and can escalate it with `-ErrorAction Stop` if it wants to,
        but by default the gather call and the worker proceed: a missing record is a
        coverage gap the harvester reports, while a unit failed because logging broke is
        worse (contract § 6.4).
      * A destination-name collision is reported as a write fault and never resolved by
        overwriting. Because `invocationId` is minted per call and cannot be supplied, a
        collision here would mean a UUIDv4 repeat or a store written by something else —
        a fact the operator needs, not one to paper over.
      * Redaction failure does not fail the write. The record is written with
        `prompt: null`, `redacted: true`, and `redactionCount: -1`, signalling
        "redaction unavailable, content withheld" rather than writing unredacted text.

    THE THREE MESSAGES A CALLER ACTUALLY MEETS, quoted so they are greppable:
      * Unbound root — TERMINATING `[System.ArgumentException]` on `WorktreeRoot`:
        "WorktreeRoot is required and must be a resolvable path. The recorder does not
        infer a worktree root by walking up to the nearest .git ancestor: an inferred root
        is indistinguishable downstream from a stated one, and it also selects the durable
        store destination. Supply -WorktreeRoot explicitly."
      * No `_Planning` sprint worktree — NON-terminating write fault, returned as `Error`:
        "No _Planning sprint worktree for Sprint <NNNN> was found beneath Git root
        '<root>'. Supply -PlanningRoot or -StoreRoot, or use -StoreTarget Generated."
      * Two `_Planning` sprint worktrees for one sprint — NON-terminating write fault,
        naming BOTH candidates rather than picking one:
        "Ambiguous _Planning sprint worktree for Sprint <NNNN> beneath '<root>':
        <name>, <name>. Supply -PlanningRoot to state which one."
      The last two are non-terminating on purpose: store resolution is a WRITE fault, and
      a recorder must never fail the gather call it is recording.

    MEASURED BEHAVIOUR AND CONSUMER-FACING CAVEATS (Task 15.183.e, 62 real records):

      * ORDINALS ARE NEITHER DENSE NOR UNIQUE. 30 concurrent records in one session scope
        collapsed onto 11 distinct `ordinal` values — gapped as well as duplicated, with
        two values assigned five times each. This is inherent to the unbound-`-Ordinal`
        fallback, which counts existing records in the scope and is therefore racy. A
        consumer MUST NOT read a gap as a missing record, and MUST NOT treat `ordinal` as
        a unique key. Total order stays well defined through contract § 8's four keys,
        whose final tiebreaker is the unique `invocationId`. Honest limit: in the measured
        run the millisecond `timestampUtc` already separated every colliding-ordinal pair,
        so the `invocationId` tiebreaker was never load-bearing and its behaviour under a
        true four-key tie is reasoned, not proven. Supplying `-Ordinal` avoids the race
        entirely and is preferred.
      * REDACTION IS KEYWORD-ANCHORED, NOT A SECRET SCANNER. The same 32-character
        high-entropy value is redacted when it follows `password=` and passes through
        untouched when it stands alone. Contract § 5.5 permits this — detection is
        best-effort — and adding an entropy heuristic would trade false passes for false
        redactions across every prompt. Treat the pattern list in `Invoke-RecordRedaction`
        as the coverage boundary, and do not paste a bare secret into a prompt on the
        assumption the recorder will catch it.
      * RESPONSE CONTENT IS PROTECTED BY NON-PERSISTENCE, NOT BY REDACTION. The redactor
        never sees `items[]`, because contract § 4 forbids persisting it at all; only the
        digest and status are stored. A record whose response carried a secret therefore
        records `redactionCount: 0`, correctly. Any future field that DID copy response
        text into a record would land outside the redaction surface and would need its own
        treatment.
      * COVERAGE CAVEAT. ContentSummary retrieval is stubbed
        (`CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED`, blocked on RDB-190, RDB-260, and
        Stream D), so today `items` is always `[]`, `itemCount` is always 0, and
        `responseDigest.value` is always the empty-array constant. The digest has no
        discriminating power until retrieval lands; the tags and prompt, which are caller
        inputs, are real seed data regardless.

    RELATED CONTRACTS — which are binding and which are parked:
      * `gather-call-record.contract.v1.md` — LIVE AND BINDING. This function implements it.
      * `worker-handoff-changed-file.contract.v1.md` and `correlated-corpus.contract.v1.md`
        — PARKED with the handoff-correlation half on 2026-08-26. They describe a future
        feature, not current behaviour; the design is carried forward in
        `handoff-correlation.deferred.v1.md`. Do not implement against them as though they
        were binding.
      All four live in
      `_Planning/InformationForTheFuture/Sprint0015/StreamM/Task15.183/`.

    NO HARVESTER EXISTS. References to "the harvester" above and in the contract describe
    the reader the format was designed for, not a function you can call: the harvesting
    function (Task 15.183.c) and the SprintEnd integration (Task 15.183.d) were parked in
    the same 2026-08-26 rescope. Records accumulate durably and are read by whatever
    consumes them next; nothing in this module reads them back.

    WHATIF: `-WhatIf` performs every computation — id, timestamp, redaction, normalization,
    digest, destination path — and skips only the two filesystem effects, creating the
    store directory and publishing the file. It returns `Ok = $true` with
    `Written = $false` and a `RecordPath` naming the file that would have been written.

  .LINK
    Save-SprintWorkSession
  .LINK
    Save-SprintRetrospectiveSnapshot
  #>
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low', DefaultParameterSetName = 'WithResponse')]
  [OutputType([PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Tags,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AgentName,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Depth = 3,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$Width = 2,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Instance = 'production',

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$Prompt = '',

    [Parameter(Mandatory = $false, ParameterSetName = 'WithResponse')]
    [AllowNull()]
    [object]$Response,

    [Parameter(Mandatory = $true, ParameterSetName = 'NoResponse')]
    [switch]$NoResponse,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$ErrorMessage,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$RequestResponsePairId,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Ordinal = 0,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$AgentModel,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$SessionId,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$TaskId,

    [Parameter(Mandatory = $false)]
    [Alias('Root')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$WorktreeRoot,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$RepositoryName,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$ConversationId,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$ConversationTitle,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$RetryOfInvocationId,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$SupersedesInvocationId,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$SprintNumber,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Stream = 'StreamM',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Durable', 'Generated')]
    [string]$StoreTarget = 'Durable',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$TaskFolder = 'Task15.183',

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$PlanningRoot,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$GitRoot,

    [Parameter(Mandatory = $false)]
    [Alias('RecordRoot', 'GatherCallsRoot', 'Path')]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$StoreRoot,

    [Parameter(Mandatory = $false)]
    [switch]$PassThruLine
  )

  begin {
    $fn = $MyInvocation.MyCommand.Name
    $mn = 'ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell'
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Entering function $fn"
    # --- private helpers ----------------------------------------------------------
    # ConvertTo-JcsJson, Get-Sha256Base16, Invoke-RecordRedaction, Get-EnvelopeMember,
    # Resolve-WorktreeRootFromPath, and Resolve-GatherCallStoreDirectory live in
    # `private/`, one function per file, per the module convention. Task 15.183.B02 moved
    # them there: they were nested inside this `begin` block only because `private/` was
    # outside the implementing unit's writable scope, never because that was their home.
    #
    # The `.psm1` dot-sources every `private/*.ps1` at import, so under a normal
    # Import-Module these are already defined and the loop below is a no-op. The fallback
    # exists for the OTHER supported entry point: dot-sourcing this single file from
    # source, which the regression suite does - including inside `ForEach-Object
    # -Parallel` runspaces, which inherit nothing and would otherwise lose every helper.
    #
    # It sits in BEGIN, not at file scope, because top-level executable code in a module
    # .ps1 runs on EVERY Import-Module. `$PSScriptRoot` still resolves correctly here.
    foreach ($helperName in @(
        'ConvertTo-JcsJson', 'Get-Sha256Base16', 'Invoke-RecordRedaction',
        'Get-EnvelopeMember', 'Resolve-WorktreeRootFromPath',
        'Resolve-GatherCallStoreDirectory')) {
      if (-not (Get-Command -Name $helperName -CommandType Function -ErrorAction SilentlyContinue)) {
        $helperPath = Join-Path $PSScriptRoot '..' 'private' "$helperName.ps1"
        if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
          . $helperPath
        }
      }
    }
  }

  process {
    # ---------------------------------------------------------------------------
    # 1. Argument faults — terminating, because each would produce a malformed record.
    # ---------------------------------------------------------------------------
    if ($PSBoundParameters.ContainsKey('Response') -and $NoResponse.IsPresent) {
      $msg = '-Response and -NoResponse are mutually exclusive: a call either received an envelope or it did not.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'GatherCallRecord', 'Argument'
      throw [System.ArgumentException]::new($msg)
    }

    # Contract 3.3: `tagsRaw` is "the tags exactly as submitted, pre-normalization, in
    # submission order" — it is the audit record of what the worker actually derived, so a
    # whitespace-only entry is retained here and discarded only by normalization. Dropping
    # it from tagsRaw would misreport what was submitted. Zero-length strings are the sole
    # exclusion, because the schema gives tagsRaw items minLength 1.
    $rawTags = @($Tags | Where-Object { $null -ne $_ -and $_.Length -gt 0 })
    if ($rawTags.Count -eq 0) {
      $msg = 'Tags is empty after discarding blank entries. An empty tag set is an argument error at the agent, not an empty result.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'GatherCallRecord', 'Argument'
      throw [System.ArgumentException]::new($msg, 'Tags')
    }

    # Contract 3.1.1: "Generated by the recorder rather than supplied by the caller, so a
    # caller cannot omit it and cannot reuse one." There is deliberately NO parameter for
    # this. Exposing one would let a caller pass the same id twice, and duplicate ids are
    # malformed (7.2) rather than something the harvester resolves — the safest place to
    # make that impossible is the parameter surface, not a validation branch.
    $invocation = [guid]::NewGuid().ToString('D').ToLowerInvariant()
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
      -Message "Minted invocationId '$invocation' for this call" -Tag 'GatherCallRecord'

    # ---------------------------------------------------------------------------
    # 2. Caller identity. Absent stays absent — nothing here is inferred from a sibling.
    # ---------------------------------------------------------------------------
    $nullIfBlank = {
      param($v)
      if ([string]::IsNullOrWhiteSpace($v)) { $null } else { $v }
    }

    $sessionIdValue = & $nullIfBlank $SessionId
    $taskIdValue = & $nullIfBlank $TaskId
    $pairIdValue = & $nullIfBlank $RequestResponsePairId
    $agentModelValue = & $nullIfBlank $AgentModel
    $conversationIdValue = & $nullIfBlank $ConversationId
    $conversationTitleValue = & $nullIfBlank $ConversationTitle
    $retryOfValue = & $nullIfBlank $RetryOfInvocationId
    $supersedesValue = & $nullIfBlank $SupersedesInvocationId

    if ($null -ne $taskIdValue -and $taskIdValue -notmatch '^[0-9]+\.[0-9]+(\.[A-Za-z0-9]+)*$') {
      $msg = "TaskId '$taskIdValue' does not match the board task pattern used by worker-handoff.schema.json."
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'GatherCallRecord', 'Argument'
      throw [System.ArgumentException]::new($msg, 'TaskId')
    }

    # FAIL CLOSED on an unbound root — ratified at the C00 gate (item 3), implemented at
    # Task 15.183.B02. This used to fall back to walking up from the current location to
    # the nearest `.git` ancestor. That was fail-OPEN, and it was wrong twice over:
    #
    #   * IDENTITY. `worktreePath` exists to say WHICH repository root a call came from.
    #     A walked-up value is inferred from ambient state, and downstream it is
    #     indistinguishable from one the caller stated — the same class of defect as an
    #     invented `conversationTitle`, which this record format refuses everywhere else.
    #   * DESTINATION. Since B02 the durable store is derived from this root's PARENT, so
    #     a walked-up root would not merely mislabel the record, it would write a
    #     sprint's seed data into whatever repository the shell happened to be sitting in.
    #
    # There is deliberately no opt-in switch to restore the walk. This is a terminating
    # argument fault rather than a returned write fault because a record carrying a
    # guessed worktreePath is malformed, and per the ERRORS section above a malformed
    # record is worse than a loud stop. Note the distinction the durable target forces:
    # the root recorded in the BODY is always the CALLING worktree, while the write
    # DESTINATION is the _Planning sprint worktree. Only the destination moved.
    $resolvedWorktree = Resolve-WorktreeRootFromPath -StartPath $WorktreeRoot
    if ($null -eq $resolvedWorktree) {
      $msg = 'WorktreeRoot is required and must be a resolvable path. The recorder does not infer a worktree root by walking up to the nearest .git ancestor: an inferred root is indistinguishable downstream from a stated one, and it also selects the durable store destination. Supply -WorktreeRoot explicitly.'
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'GatherCallRecord', 'Argument'
      throw [System.ArgumentException]::new($msg, 'WorktreeRoot')
    }

    $repositoryNameValue = & $nullIfBlank $RepositoryName
    if ($null -eq $repositoryNameValue -and $null -ne $resolvedWorktree) {
      # Contract 3.2: recorded "ONLY when it can be read from git or the worktree path
      # DETERMINISTICALLY; otherwise null."
      #
      # The only deterministic signal in a path is the sprint-worktree grammar
      # `<repo>-wt-<issue>-Sprint-<NNNN>-work-items`. Treating any other directory name as
      # a repository name is not derivation, it is a guess: an arbitrary parent folder
      # would be recorded as though it were a repository, and an invented repositoryName is
      # indistinguishable downstream from a real one. That is precisely the failure this
      # whole record is meant to prevent, so an unrecognized path records null.
      $leaf = Split-Path -Path $resolvedWorktree -Leaf
      if ($leaf -match '^(?<repo>.+)-wt-\d+-Sprint-\d{4}-work-items$') {
        $repositoryNameValue = $Matches['repo']
      }
    }

    # ---------------------------------------------------------------------------
    # 3. Redaction, then normalization. Order matters: `tags` is normalized from the
    #    REDACTED raw tags, so a secret pasted into a tag cannot survive into either array.
    # ---------------------------------------------------------------------------
    $redactionAvailable = $true
    $redactionCount = 0
    $promptValue = $Prompt
    $errorMessageValue = & $nullIfBlank $ErrorMessage
    $redactedRawTags = $rawTags

    try {
      $promptRedaction = Invoke-RecordRedaction -Text $Prompt
      $promptValue = $promptRedaction.Text
      $redactionCount += $promptRedaction.Count

      if ($null -ne $errorMessageValue) {
        $errorRedaction = Invoke-RecordRedaction -Text $errorMessageValue
        $errorMessageValue = $errorRedaction.Text
        $redactionCount += $errorRedaction.Count
      }

      $redactedRawTags = @(foreach ($t in $rawTags) {
          $tagRedaction = Invoke-RecordRedaction -Text $t
          $redactionCount += $tagRedaction.Count
          $tagRedaction.Text
        })
    } catch {
      # Fail safe toward withholding. A shortened prompt is indistinguishable from a short
      # prompt, so the sentinel is explicit rather than a silent truncation.
      $redactionAvailable = $false
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error `
        -Message "Redaction unavailable, withholding prompt content: $($_.Exception.Message)" `
        -Tag 'GatherCallRecord', 'Redaction'
      $promptValue = $null
      $errorMessageValue = $null
      $redactedRawTags = @('[REDACTED:secret]')
      $redactionCount = -1
    }

    $normalizedTags = [System.Collections.Generic.List[string]]::new()
    foreach ($t in $redactedRawTags) {
      $n = $t.Trim()
      if ($n.Length -eq 0) { continue }
      $n = $n.ToLowerInvariant()
      $n = [regex]::Replace($n, '\s+', '-')
      if ($n.Length -eq 0) { continue }
      if (-not $normalizedTags.Contains($n)) { [void]$normalizedTags.Add($n) }
    }
    $normalizedArray = [string[]]$normalizedTags.ToArray()
    [array]::Sort($normalizedArray, [System.StringComparer]::Ordinal)

    # ---------------------------------------------------------------------------
    # 4. Outcome derivation — mechanical, per contract § 3.4. Nothing below is a
    #    judgement call, which is why none of these fields is a parameter.
    # ---------------------------------------------------------------------------
    $envelope = $null
    $envelopeReceived = $false
    $parseFailed = $false

    if (-not $NoResponse.IsPresent -and $null -ne $Response) {
      if ($Response -is [string]) {
        try {
          $envelope = $Response | ConvertFrom-Json -ErrorAction Stop
          $envelopeReceived = $true
        } catch {
          $parseFailed = $true
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
            -Message "Response could not be parsed as JSON; recording outcome 'failure': $($_.Exception.Message)" `
            -Tag 'GatherCallRecord'
        }
      } else {
        $envelope = $Response
        $envelopeReceived = $true
      }
    }

    $responseStatus = $null
    $stubMarker = $null
    $stubBlockedBy = $null
    $itemCount = $null
    $truncatedValue = $null
    $responseDigest = $null
    $outcome = 'failure'

    if ($envelopeReceived) {
      $responseStatus = & $nullIfBlank ([string](Get-EnvelopeMember -Envelope $envelope -Name 'status'))
      $stub = Get-EnvelopeMember -Envelope $envelope -Name 'stub'
      $items = Get-EnvelopeMember -Envelope $envelope -Name 'items'
      if ($null -eq $items) { $items = @() }
      $itemCount = @($items).Count
      $truncatedRaw = Get-EnvelopeMember -Envelope $envelope -Name 'truncated'
      $truncatedValue = [bool]$truncatedRaw
      $envelopeError = & $nullIfBlank ([string](Get-EnvelopeMember -Envelope $envelope -Name 'error'))

      if ($null -ne $stub) {
        $stubMarker = & $nullIfBlank ([string](Get-EnvelopeMember -Envelope $stub -Name 'marker'))
        $blocked = Get-EnvelopeMember -Envelope $stub -Name 'blockedBy'
        if ($null -ne $blocked) { $stubBlockedBy = [string[]]@($blocked) }
      }

      if ($null -eq $errorMessageValue -and $null -ne $envelopeError) {
        # An envelope error the caller did not pass explicitly still belongs in the record;
        # redact it on the same terms as everything else.
        if ($redactionAvailable) {
          $envelopeErrorRedaction = Invoke-RecordRedaction -Text $envelopeError
          $errorMessageValue = $envelopeErrorRedaction.Text
          $redactionCount += $envelopeErrorRedaction.Count
        }
      }

      # Contract § 3.4, evaluated in the contract's own order.
      if ($null -ne $stub -or $responseStatus -eq 'NotImplemented' -or $stubMarker -eq 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED') {
        $outcome = 'stubbed'
        if ($null -eq $stubMarker) {
          # A stubbed outcome without a marker loses the discriminator the whole stub
          # contract rests on, so record the canonical marker the status implies.
          $stubMarker = 'CONTENT_SUMMARY_RETRIEVAL_NOT_IMPLEMENTED'
        }
      } elseif ($responseStatus -eq 'ok' -and $null -eq $envelopeError -and -not $truncatedValue) {
        $outcome = 'success'
      } elseif ($responseStatus -eq 'ok' -and $null -eq $envelopeError -and $truncatedValue) {
        $outcome = 'partial'
      } else {
        $outcome = 'failure'
      }

      $canonicalItems = ConvertTo-JcsJson -Value ([object[]]@($items))
      $responseDigest = [ordered]@{
        algorithm        = 'SHA-256'
        canonicalization = 'rfc8785-jcs'
        encoding         = 'base16-lower'
        input            = 'items'
        value            = (Get-Sha256Base16 -Text $canonicalItems)
      }
    } else {
      # No envelope, or an envelope that would not parse. Both are 'failure', and both
      # record nulls rather than zeros: 0 items is a fact, "no envelope" is not.
      $outcome = 'failure'
      if ($parseFailed -and $null -eq $errorMessageValue -and $redactionAvailable) {
        $errorMessageValue = 'Response could not be parsed as JSON.'
      }
    }

    # ---------------------------------------------------------------------------
    # 5. Store location. Supplying -StoreRoot bypasses all resolution, which is the
    #    seam a test uses; nothing here hardcodes a host path. Otherwise the target is
    #    composed by Resolve-GatherCallStoreDirectory from the sprint context, and which
    #    of the two layouts it composes is the caller-visible -StoreTarget decision.
    #
    #    Resolution failures come back as Ok=$false with an actionable message rather
    #    than as exceptions, because a store that cannot be resolved is a WRITE fault
    #    (contract 6.4, non-terminating) — unlike the unbound root above, which is an
    #    argument fault. The one exception is a malformed explicit -SprintNumber, which
    #    the resolver throws for, preserving this function's prior behaviour.
    # ---------------------------------------------------------------------------
    $ok = $true
    $writeError = $null
    $storeDirectory = & $nullIfBlank $StoreRoot

    if ($null -eq $storeDirectory) {
      $storeResolution = Resolve-GatherCallStoreDirectory `
        -StoreTarget $StoreTarget `
        -WorktreeRoot $resolvedWorktree `
        -SprintNumber $SprintNumber `
        -Stream $Stream `
        -TaskFolder $TaskFolder `
        -PlanningRoot $PlanningRoot `
        -GitRoot $GitRoot

      if ($storeResolution.Ok) {
        $storeDirectory = $storeResolution.Directory
      } else {
        $writeError = $storeResolution.Error
        $ok = $false
      }
    }

    # ---------------------------------------------------------------------------
    # 6. Ordinal — a 1-based counter that must ADVANCE across records in the same scope.
    #
    #    `ordinalScope` is `session` when the harness exposed a session id and `file`
    #    otherwise. In the sharded layout the counting domain for BOTH scopes is the store
    #    directory, because the harvester treats every `*.jsonl` file under `gather-calls/`
    #    as one logical stream (contract 6.2). Reading contract 3.1.2's "scoped to the
    #    record file" as "always 1" would be correct only for an unsharded single-file
    #    store; under sharding it would make every sessionless ordinal 1, which destroys
    #    the fallback ordering that ordinal exists to provide when
    #    `requestResponsePairId` is null.
    #
    #    So: count the records already in the store that share this scope key — same
    #    session id, or `null` for the sessionless case — and take the next number. The
    #    same scan serves both scopes, which is why there is one code path here.
    # ---------------------------------------------------------------------------
    $ordinalScope = if ($null -ne $sessionIdValue) { 'session' } else { 'file' }
    $ordinalValue = $Ordinal

    if ($ordinalValue -lt 1) {
      # Derivation is a non-atomic read, so two calls racing inside ONE scope can compute
      # the same ordinal. That is bounded and survivable: contract 8 makes `invocationId`
      # the final tiebreaker, so the total order stays well defined and no record is lost
      # or overwritten. Callers that need a guaranteed-gap-free sequence supply -Ordinal.
      # Concurrent WRITERS normally carry distinct session ids, so they do not share a
      # scope key and do not contend here at all.
      $ordinalValue = 1
      if ($null -ne $storeDirectory -and (Test-Path -LiteralPath $storeDirectory -PathType Container)) {
        try {
          $sessionToken = ConvertTo-JcsJson -Value $sessionIdValue
          $needle = '"sessionId":' + $sessionToken
          $seen = 0
          foreach ($f in (Get-ChildItem -LiteralPath $storeDirectory -Filter '*.jsonl' -File -ErrorAction Stop)) {
            if ($f.Extension -ne '.jsonl') { continue }
            $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
            # Ordinal (not -like) so no character of the session id is treated as a
            # wildcard, and the trailing delimiter check keeps "sess-1" from matching
            # a record whose session is "sess-11".
            $at = $content.IndexOf($needle, [System.StringComparison]::Ordinal)
            if ($at -ge 0) {
              $nextChar = if (($at + $needle.Length) -lt $content.Length) { $content[$at + $needle.Length] } else { ',' }
              if ($nextChar -eq ',' -or $nextChar -eq '}') { $seen++ }
            }
          }
          $ordinalValue = $seen + 1
        } catch {
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
            -Message "Ordinal derivation scan failed, defaulting to 1: $($_.Exception.Message)" `
            -Tag 'GatherCallRecord'
          $ordinalValue = 1
        }
      }
    }

    # ---------------------------------------------------------------------------
    # 7. Serialize. Key order is ordinal-sorted by the serializer, which is part of the
    #    format: it is what lets the terminal-less half reproduce this line exactly.
    # ---------------------------------------------------------------------------
    $issuedAt = [datetime]::UtcNow
    $timestampUtc = $issuedAt.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)

    $record = [ordered]@{
      agentModel             = $agentModelValue
      agentName              = $AgentName
      conversationId         = $conversationIdValue
      conversationTitle      = $conversationTitleValue
      depth                  = $Depth
      errorMessage           = $errorMessageValue
      instance               = $Instance
      invocationId           = $invocation
      itemCount              = $itemCount
      ordinal                = $ordinalValue
      ordinalScope           = $ordinalScope
      outcome                = $outcome
      prompt                 = $promptValue
      recordVersion          = '1.0.0'
      redacted               = ($redactionCount -ne 0)
      redactionCount         = $redactionCount
      repositoryName         = $repositoryNameValue
      requestResponsePairId  = $pairIdValue
      responseDigest         = $responseDigest
      responseStatus         = $responseStatus
      retryOfInvocationId    = $retryOfValue
      sessionId              = $sessionIdValue
      stubBlockedBy          = $stubBlockedBy
      stubMarker             = $stubMarker
      supersedesInvocationId = $supersedesValue
      tags                   = $normalizedArray
      tagsRaw                = [string[]]@($redactedRawTags)
      taskId                 = $taskIdValue
      timestampUtc           = $timestampUtc
      truncated              = $truncatedValue
      width                  = $Width
      worktreePath           = $resolvedWorktree
    }

    $line = ConvertTo-JcsJson -Value $record

    $fileStamp = $issuedAt.ToString('yyyyMMddTHHmmssfff', [System.Globalization.CultureInfo]::InvariantCulture) + 'Z'
    $recordFileName = "$fileStamp-$invocation.jsonl"
    $recordPath = if ($null -ne $storeDirectory) { Join-Path $storeDirectory $recordFileName } else { $null }

    # ---------------------------------------------------------------------------
    # 8. Publish. Stage, force to stable storage, then rename. Move refuses to overwrite,
    #    so publication is create-only and a collision fails loudly.
    # ---------------------------------------------------------------------------
    $written = $false
    if ($ok) {
      if ($PSCmdlet.ShouldProcess($recordPath, 'Write gather-call record')) {
        $tempPath = $null
        try {
          if (-not (Test-Path -LiteralPath $storeDirectory -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $storeDirectory -Force -ErrorAction Stop)
          }

          $tempPath = Join-Path $storeDirectory ('_partial-{0}.tmp' -f [guid]::NewGuid().ToString('N'))
          $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($line + "`n")

          $fs = [System.IO.FileStream]::new(
            $tempPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None)
          try {
            $fs.Write($bytes, 0, $bytes.Length)
            $fs.Flush($true)
          } finally {
            $fs.Dispose()
          }

          # Two-argument Move throws when the destination exists. That refusal IS the
          # concurrency guarantee; do not replace it with an overwriting move.
          [System.IO.File]::Move($tempPath, $recordPath)
          $tempPath = $null
          $written = $true

          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
            -Message "Wrote gather-call record '$recordFileName' (outcome=$outcome, ordinal=$ordinalValue/$ordinalScope)" `
            -Tag 'GatherCallRecord'
        } catch {
          $ok = $false
          $writeError = "Failed to write gather-call record to '$recordPath': $($_.Exception.Message)"
          if ($null -ne $tempPath) {
            try { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue } catch { }
          }
        }
      } else {
        Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Verbose `
          -Message "WhatIf: gather-call record '$recordFileName' not written" -Tag 'GatherCallRecord'
      }
    }

    if (-not $ok) {
      # Explicit on three channels, terminating on none of them: a recorder failure must
      # not fail the gather call or the worker (contract § 6.4), but it must never be
      # silent either. A caller that wants it fatal uses -ErrorAction Stop.
      Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $writeError -Tag 'GatherCallRecord', 'WriteFailure'
      Write-Error -Message $writeError -Category WriteError -TargetObject $recordPath -ErrorAction Continue
    }

    $result = [PSCustomObject]@{
      Ok              = $ok
      Written         = $written
      RecordPath      = $recordPath
      RecordDirectory = $storeDirectory
      InvocationId    = $invocation
      Ordinal         = $ordinalValue
      OrdinalScope    = $ordinalScope
      TimestampUtc    = $timestampUtc
      Outcome         = $outcome
      RecordVersion   = '1.0.0'
      Redacted        = ($redactionCount -ne 0)
      RedactionCount  = $redactionCount
      Record          = ([PSCustomObject]$record)
      Line            = $(if ($PassThruLine.IsPresent) { $line } else { $null })
      Error           = $writeError
    }

    $result
  }

  end {
    Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Debug -Message "Exiting function $fn"
  }
}
