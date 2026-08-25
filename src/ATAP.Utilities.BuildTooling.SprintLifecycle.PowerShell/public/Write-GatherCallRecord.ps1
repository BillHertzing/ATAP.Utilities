# Load contract: dot-sourcing this file defines Write-GatherCallRecord and does nothing
# else. There is no top-level executable code, no module-scope constant, and no alias —
# every constant this function needs (the record version, the digest algorithm, the
# canonical key order) is computed or declared inside the function body, so importing the
# module never touches the filesystem.
function Write-GatherCallRecord {
  <#
  .SYNOPSIS
    Appends exactly one gather-call record to the append-only record store under a sprint
    worktree's `_generated` tree, concurrency-safely, for a single
    `gather-content-summary` invocation.

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

    beneath

        <WorktreeRoot>/_generated/Sprint<NNNN>/<Stream>/gather-calls/

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
    Absolute path of the worktree root the caller is running in. When omitted it is found
    by walking up from the current location to the nearest directory containing a `.git`
    entry — the repository's normal resolution path, with no host path hardcoded. Recorded
    as `worktreePath` with forward slashes and no trailing slash.

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
    The `gather-calls` directory itself. Supplying it bypasses worktree and sprint
    resolution entirely, which is how a test points the writer at a temporary directory.
    Aliases: `RecordRoot`, `GatherCallsRoot`, `Path`.

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

  .EXAMPLE
    $envelope = Get-Content ./response.json -Raw
    Write-GatherCallRecord -Tags @('handoff','schema') -AgentName 'junior-dev-coder-sh' `
      -TaskId '15.183.B01' -Prompt 'Context for the recorder unit' -Response $envelope

    Writes one record for a completed call. Because retrieval is stubbed the envelope
    carries a `stub` key, so `outcome` is `stubbed` — a first-class outcome, not a failure.

  .EXAMPLE
    try { $envelope = ... } catch {
      Write-GatherCallRecord -Tags @('handoff') -AgentName 'junior-dev-coder-jm' `
        -NoResponse -ErrorMessage $_.Exception.Message
    }

    The failure case the recorder exists to catch: a call that never returned an envelope
    is still recorded, with outcome 'failure' and the redacted exception message.

  .EXAMPLE
    Write-GatherCallRecord -Tags @('drift') -AgentName 'junior-dev-coder-jl' `
      -StoreRoot (Join-Path $TestDrive 'gather-calls') -WhatIf

    Computes the record and the destination path, returns the object, and writes nothing.

  .EXAMPLE
    $r = Write-GatherCallRecord -Tags @('drift') -AgentName 'x' -StoreRoot $dir
    if (-not $r.Ok) { Write-PSFMessage -Level Error -Message $r.Error }

    The non-blocking failure contract: a recorder failure must never fail the gather call
    or the worker, so the failure is returned rather than thrown.

  .NOTES
    Task 15.183.B01 (Sprint 0015, Stream M). Implements
    `gather-call-record.contract.v1.md` recordVersion 1.0.0.

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

    # --- nested helpers -----------------------------------------------------------
    # Defined here rather than at file scope so that dot-sourcing this file during module
    # import defines the public function and nothing else, per the repo module standard.

    # RFC 8785 (JCS) serialization of the value subset this record uses: null, boolean,
    # integer, floating point, string, array, and object. Object keys are sorted by UTF-16
    # code unit, which is both the JCS rule and the rule that makes the record line
    # reproducible by a caller that has no serializer at all.
    function ConvertTo-JcsJson {
      param([Parameter(Mandatory = $false)][AllowNull()][object]$Value)

      if ($null -eq $Value) { return 'null' }

      if ($Value -is [string]) {
        # if/elseif rather than switch: `continue` inside a switch nested in a loop has
        # loop-continuation semantics that are easy to get subtly wrong, and a mis-escaped
        # control character would produce an unparseable record line.
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append('"')
        foreach ($ch in $Value.ToCharArray()) {
          $code = [int]$ch
          if ($code -eq 0x22) { [void]$sb.Append('\"') }
          elseif ($code -eq 0x5C) { [void]$sb.Append('\\') }
          elseif ($code -eq 0x08) { [void]$sb.Append('\b') }
          elseif ($code -eq 0x09) { [void]$sb.Append('\t') }
          elseif ($code -eq 0x0A) { [void]$sb.Append('\n') }
          elseif ($code -eq 0x0C) { [void]$sb.Append('\f') }
          elseif ($code -eq 0x0D) { [void]$sb.Append('\r') }
          elseif ($code -lt 0x20) { [void]$sb.Append(('\u{0:x4}' -f $code)) }
          else { [void]$sb.Append($ch) }
        }
        [void]$sb.Append('"')
        return $sb.ToString()
      }

      if ($Value -is [bool]) { return $(if ($Value) { 'true' } else { 'false' }) }

      if ($Value -is [int] -or $Value -is [long] -or $Value -is [int16] -or $Value -is [byte]) {
        return ([long]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture)
      }

      if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        $d = [double]$Value
        if ([double]::IsNaN($d) -or [double]::IsInfinity($d)) {
          throw "ConvertTo-JcsJson: NaN and Infinity have no JSON representation."
        }
        if ($d -eq [Math]::Floor($d) -and [Math]::Abs($d) -lt 1e15) {
          return ([long]$d).ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }
        return $d.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
      }

      if ($Value -is [System.Collections.IDictionary]) {
        $keys = [string[]]@($Value.Keys)
        [array]::Sort($keys, [System.StringComparer]::Ordinal)
        $parts = foreach ($k in $keys) {
          '{0}:{1}' -f (ConvertTo-JcsJson -Value $k), (ConvertTo-JcsJson -Value $Value[$k])
        }
        return '{' + ($parts -join ',') + '}'
      }

      # Compared by full type name rather than with -is, because -is unwraps the PSObject
      # adapter and the result for a PSCustomObject is not dependable across hosts.
      if ($Value.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
        $keys = [string[]]@($Value.PSObject.Properties.Name)
        [array]::Sort($keys, [System.StringComparer]::Ordinal)
        $parts = foreach ($k in $keys) {
          '{0}:{1}' -f (ConvertTo-JcsJson -Value $k), (ConvertTo-JcsJson -Value $Value.$k)
        }
        return '{' + ($parts -join ',') + '}'
      }

      if ($Value -is [System.Collections.IEnumerable]) {
        $parts = foreach ($item in $Value) { ConvertTo-JcsJson -Value $item }
        return '[' + ($parts -join ',') + ']'
      }

      # Anything else is recorded by its invariant string form rather than dropped, so an
      # unexpected type degrades to a readable value instead of a silent null.
      return (ConvertTo-JcsJson -Value ([string]$Value))
    }

    function Get-Sha256Base16 {
      param([Parameter(Mandatory = $true)][string]$Text)
      $sha = [System.Security.Cryptography.SHA256]::Create()
      try {
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return -join ($hash | ForEach-Object { $_.ToString('x2') })
      } finally {
        $sha.Dispose()
      }
    }

    # Best-effort, fail-safe-toward-redaction. Ordered most-specific first so that a PEM
    # body is not first partially eaten by the generic credential pattern.
    function Invoke-RecordRedaction {
      param([Parameter(Mandatory = $false)][AllowNull()][AllowEmptyString()][string]$Text)

      if ([string]::IsNullOrEmpty($Text)) {
        return [PSCustomObject]@{ Text = $Text; Count = 0 }
      }

      $patterns = @(
        @{ Kind = 'key'; Pattern = '-----BEGIN[A-Z ]*PRIVATE KEY-----[\s\S]*?-----END[A-Z ]*PRIVATE KEY-----' },
        @{ Kind = 'key'; Pattern = '-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----' },
        # Only the genuinely sensitive keys of a connection string. `Server`, `Data
        # Source`, `Initial Catalog`, and `User Id` are not secret VALUES, and matching
        # them bought no safety while causing real collateral: the value class runs to the
        # next `;` or end of line, so a match on a trailing non-secret segment swallowed
        # the rest of the prompt — including text a later pattern would have classified
        # more precisely. Over-redaction is the correct direction, but not at the cost of
        # mislabelling every following token as part of a connection string.
        # The value class stops at whitespace as well as at `;`. Running to the next `;` or
        # end of line meant a prompt like `prefix Password=x suffix` lost ` suffix` along
        # with the secret — a silent deletion, which contract 5.2 forbids: redaction must be
        # VISIBLE, because a silently shortened prompt is indistinguishable from a short
        # one. Secret values in connection strings do not contain spaces, so bounding at
        # whitespace costs no coverage; a value that genuinely contained a space would have
        # its leading portion redacted and the remainder is caught by the credential
        # pattern below.
        @{ Kind = 'connection-string'; Pattern = '(?i)\b(?:password|pwd|accountkey|shared\s*access\s*key)\s*=\s*[^;''"\s\r\n]+' },
        @{ Kind = 'token'; Pattern = '(?i)\bbearer\s+[A-Za-z0-9._~+/\-]{16,}=*' },
        @{ Kind = 'token'; Pattern = '\bgh[pousr]_[A-Za-z0-9]{16,}' },
        @{ Kind = 'token'; Pattern = '\beyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}' },
        @{ Kind = 'token'; Pattern = '(?i)\bxox[baprs]-[A-Za-z0-9\-]{10,}' },
        @{ Kind = 'credential'; Pattern = '(?i)\b(?:password|passwd|pass|secret|apikey|api[_\-]?key|access[_\-]?key|client[_\-]?secret|token|credential)\s*[:=]\s*["'']?[^\s"''`;,\r\n]{6,}' },
        @{ Kind = 'secret'; Pattern = '(?i)\b(?:AKIA|ASIA)[A-Z0-9]{16}\b' }
      )

      # SINGLE PASS over the ORIGINAL text, first-pattern-wins on overlap.
      #
      # Applying the patterns in sequence, each to the output of the last, double-counts
      # and mislabels: a `token: ghp_xxx` fragment is redacted once by the token pattern,
      # and the generic credential pattern then matches the SURVIVING `token: [REDACTED..]`
      # and redacts it again. That inflates `redactionCount` — which consumers use to
      # decide whether a record needs review — and overwrites the precise `token` kind with
      # the vague `credential` one. Collecting spans against the original text and
      # resolving overlaps in pattern order fixes both: the count is exactly the number of
      # distinct secrets found, and each span keeps the kind of the most specific pattern
      # that claimed it.
      $spans = [System.Collections.Generic.List[object]]::new()
      foreach ($p in $patterns) {
        foreach ($m in [regex]::Matches($Text, $p.Pattern)) {
          $start = $m.Index
          $end = $m.Index + $m.Length
          $overlaps = $false
          foreach ($s in $spans) {
            if ($start -lt $s.End -and $end -gt $s.Start) { $overlaps = $true; break }
          }
          if (-not $overlaps) {
            [void]$spans.Add([PSCustomObject]@{ Start = $start; End = $end; Kind = $p.Kind })
          }
        }
      }

      if ($spans.Count -eq 0) {
        return [PSCustomObject]@{ Text = $Text; Count = 0 }
      }

      $ordered = @($spans | Sort-Object -Property Start)
      $sb = [System.Text.StringBuilder]::new()
      $cursor = 0
      foreach ($s in $ordered) {
        [void]$sb.Append($Text.Substring($cursor, $s.Start - $cursor))
        [void]$sb.Append('[REDACTED:{0}]' -f $s.Kind)
        $cursor = $s.End
      }
      [void]$sb.Append($Text.Substring($cursor))

      return [PSCustomObject]@{ Text = $sb.ToString(); Count = $ordered.Count }
    }

    function Get-EnvelopeMember {
      param(
        [Parameter(Mandatory = $true)][AllowNull()][object]$Envelope,
        [Parameter(Mandatory = $true)][string]$Name
      )
      if ($null -eq $Envelope) { return $null }
      if ($Envelope -is [System.Collections.IDictionary]) {
        if ($Envelope.Contains($Name)) { return $Envelope[$Name] }
        return $null
      }
      $prop = $Envelope.PSObject.Properties[$Name]
      if ($null -eq $prop) { return $null }
      return $prop.Value
    }

    function Resolve-WorktreeRootFromPath {
      param([Parameter(Mandatory = $true)][string]$StartPath)
      $dir = $null
      try { $dir = [System.IO.DirectoryInfo]::new($StartPath) } catch { return $null }
      while ($null -ne $dir) {
        if (Test-Path -LiteralPath (Join-Path $dir.FullName '.git')) { return $dir.FullName }
        $dir = $dir.Parent
      }
      return $null
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

    $resolvedWorktree = & $nullIfBlank $WorktreeRoot
    if ($null -eq $resolvedWorktree) {
      $resolvedWorktree = Resolve-WorktreeRootFromPath -StartPath (Get-Location).Path
    }
    if ($null -ne $resolvedWorktree) {
      $resolvedWorktree = ($resolvedWorktree -replace '\\', '/').TrimEnd('/')
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
    #    seam a test uses; nothing here hardcodes a host path.
    # ---------------------------------------------------------------------------
    $ok = $true
    $writeError = $null
    $storeDirectory = & $nullIfBlank $StoreRoot

    if ($null -eq $storeDirectory) {
      if ($null -eq $resolvedWorktree) {
        $writeError = "Could not resolve a worktree root from '$((Get-Location).Path)' (no ancestor contains a .git entry). Supply -WorktreeRoot or -StoreRoot."
        $ok = $false
      } else {
        $sprint = & $nullIfBlank $SprintNumber
        if ($null -eq $sprint -and $resolvedWorktree -match '-Sprint-(\d{4})-work-items') {
          $sprint = $Matches[1]
        }
        if ($null -eq $sprint) {
          $writeError = "Could not resolve a sprint number from worktree '$resolvedWorktree'. Supply -SprintNumber or -StoreRoot."
          $ok = $false
        } elseif ($sprint -notmatch '^\d{4}$') {
          $msg = "SprintNumber '$sprint' is not four digits."
          Write-PSFMessage -FunctionName $fn -ModuleName $mn -Level Error -Message $msg -Tag 'GatherCallRecord', 'Argument'
          throw [System.ArgumentException]::new($msg, 'SprintNumber')
        } else {
          $storeDirectory = Join-Path (Join-Path (Join-Path (Join-Path $resolvedWorktree '_generated') ("Sprint$sprint")) $Stream) 'gather-calls'
        }
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
