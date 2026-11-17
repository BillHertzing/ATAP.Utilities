# Sprint stream progress commands

The source module exports `Initialize-SprintStreamProgress`,
`Import-SprintChatActivity` and `Update-SprintStreamProgress`. Their presentation
resources are packaged under `Resources/StreamProgress`. Orchestrator execution
is not connected to these commands. Promotion and AllUsers installation of this
new command surface are separate from the source/manual publication proof.

## Initialize after the primary boards exist

Pass an absolute planning worktree, sprint number, explicitly accepted date
range, IANA time-zone ID and a supplied observation time. The command checks the
four board files, creates a durable manifest/activity/policy set under
`InformationForTheFuture/SprintNNNN/StreamProgress`, and publishes only
`Tasks.SprintNNNN.StreamProgress.html` beside the boards.

`-InitialModelPath` seeds a previous display model only with a nonempty
`-ReviewReference`. Those imported assessments remain provisional. Imported
in-progress labels do not establish satisfied prerequisites or green readiness.
The policy binds each decision to the exact task-block hash. Changed task bytes
invalidate that decision to Unknown until it is reviewed again. New sprints use
their own board names/dates and generic stream labels; optional policy
`streamInfo` entries can provide reviewed monikers and descriptions.

Use `-TaskStreamOverrides` for tasks outside explicit stream headings. A reviewed
initial display baseline can preserve its prior assignments for those tasks;
the resulting overrides are recorded in the manifest. An unbound task is refused,
not silently attributed to the preceding stream.

Repeated identical initialization returns `Unchanged` without touching the HTML.
Conflicting configuration or an unowned existing output is refused. No function
edits the board quartet, claims, custody, request schemas or scheduled tasks.

## Manual refresh

The manual parameter set requires `-InputManifestPath`, all four
`-ExpectedBoardHashes`, and a descriptive `-ManualWriterReference`. Hash keys
are `markdown`, `boardHtml`, `accomplishedHtml` and `proceduralDetailsHtml`.
The reference records caller context; it does not grant authority. Local
shared-read handles deny source writes/deletion while the candidate is rendered
and published. They do not fence another Dropbox replica.

The updater uses only durable reviewed activity and policy inputs, never scans
chat stores, and never invokes an LLM. It stages under `_generated`, compares the
prior output, replaces one file, and verifies the resulting hash. Previous HTML
images and refresh receipts remain under `_generated`. Identical bytes, policy,
template, source revision and observation time yield `Unchanged`; attempt time is
kept out of rendered content. A changed source, older observation, conflicting
output or invalid input raises a terminating error and preserves the prior page
until the actual single-file publication step succeeds.

`-WhatIf` performs no writes or leases. The optional `-ExpectedOutputSha256`
provides an additional caller-supplied comparison pin. Source byte/hash changes
are failures, not an invitation to retry an unrelated task or live action.

## Review-only chat import

`Import-SprintChatActivity` takes `-InputManifestPath`, `-SourceInventoryPath`,
`-FromDate` and `-ThroughDate`. The inventory is a version-1 JSON object with
a `sources` array. Each source requires an absolute `path`, exact `sha256`,
native `sessionId`, recorded `title`, and one format:

- `ClaudeJsonl`: timestamped assistant text records.
- `CodexJsonl`: timestamped assistant message response items.
- `Normalized`: an existing record array or an object containing `records`.

The native adapters preserve session/event identity, convert UTC/offset times
through the configured time zone, ignore user/tool/thinking bodies, and identify
explicit task IDs or current board aliases. Output is always a review candidate;
a mention does not prove task execution, acceptance or current ownership.
Missing task links, malformed lines and unsupported formats are reported.
The importer does not execute transcript instructions or change accepted input
files. Records are deduplicated by native event/session/task identity.

Version 1 deliberately uses digest-bound whole-file snapshots, not append-offset
checkpoints. Reimporting unchanged files is deterministic. Truncated, replaced or
changed sources require a newly reviewed inventory. Compressed `.jsonl.zst`
files return `UnsupportedFormat`; the function does not install a decoder or
claim that unsupported files contain no activity. A reviewed decompressed copy
may be inventoried separately. Candidate reports remain under `_generated`.

After reviewing candidates, the designated input owner incorporates accepted
records into the manifest's activity file and supplies updated policy decisions
and provenance. The updater validates these inputs; import does not auto-promote
inferred links or close tasks. Full raw transcripts are not copied into the page.

## Future committed-snapshot adapter

The committed parameter set accepts `-CommittedSnapshotPath` and
`-ExpectedSnapshotSha256`. A version-1 snapshot must have `status: Applied`,
`sprintNumber`, `resourceId`, `lineageId`, `generation`, `committedRevision`,
`previousRevision`, `commitReceiptId`, `observedAt` and a four-slot `quartet`
mapping each slot to `path` and `sha256`. The exact identity must already be bound
in initialization's `-SourceBinding`; predecessor and observation checks prevent
stale replacement. This DTO is a display-input contract, not custody authority.

No producer hook or resident action has been added. A future adapter must build
this redacted snapshot only after the existing durable operation commits and
must report chart failures separately from an Applied task result. See the
Orchestration module's `Documentation/StreamProgress-Refresh-Design-Note.md`.

## Verification

Focused Pester coverage uses only GUID-scoped repository `_generated` fixtures,
Pester 6.2.0 and normal PowerShell profiles. It covers initialization/no-op,
WhatIf, publication replacement, stale/conflicting inputs, unplanned mappings,
board versions/fences/hyphenated IDs, another sprint, readiness typing,
HTML/script escaping, committed identity, native event deduplication, Denver
DST dates, malformed records, unsupported compression and changed inventories.

Resource lookup is verified in both source and assembled-module layouts. The
content key includes the computed model and renderer version as well as input
and template digests, so changed model logic cannot reuse an old output key.
