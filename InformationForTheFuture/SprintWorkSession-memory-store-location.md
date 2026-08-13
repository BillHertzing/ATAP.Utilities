# Handoff: `/checkpoint` silently skips the memory snapshot for some worktrees

**Status:** RESOLVED 2026-08-05. Shipped in
`ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell` 0.1.31, installed AllUsers, and
verified end to end by a real checkpoint from the affected worktree returning
`MemoryFileCount = 9` where every prior run recorded 0. Discovered 2026-08-05 during Sprint 0014 Stream L work in
`SharedVSCode-wt-62-Sprint-0014-work-items`.
**Component:** `ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell` →
`public/Save-SprintWorkSession.ps1`
**Consumer:** the `checkpoint` skill (`/checkpoint`, `/cp`), rendered from
`SharedVSCode/.ai/skills/checkpoint/SKILL.md`.
**Scope of this document:** one issue only — memory-store path resolution. It is not a
review of `Save-SprintWorkSession` generally.

---

## The one-paragraph version

`Save-SprintWorkSession` resolves the Claude Code **memory** directory as a child of
whichever project directory the **transcript** search happened to settle on. The two are
not independently located. There is already a stable-repo-slug fallback for the transcript,
but it is gated on the transcript being missing — so when the transcript *is* found under
the sprint-worktree slug and the memory store lives only under the stable-repo slug, memory
resolution never gets a second chance. The result is a checkpoint that reports success,
writes a conversation archive, appends a roster entry, and captures **zero memory files**,
with the outcome recorded as an ordinary "directory not found" skip that is
indistinguishable in the roster from an agent that legitimately has no memory store.

---

## Verified facts

Each claim below is tagged with the artifact that proves it. Nothing in this section is
inference.

| # | Claim | Evidence |
|---|---|---|
| V1 | Memory is resolved from the transcript's directory, not located independently. | `Save-SprintWorkSession.ps1:437` — `$memSrcDir = Resolve-CaseInsensitiveChildDirectory -ParentPath $sessionDir -ChildName 'memory'`, where `$sessionDir` is whatever the transcript search set. |
| V2 | The stable-slug fallback is gated on the transcript, not on memory. | `Save-SprintWorkSession.ps1:412` — `if (-not $jsonl) { ... }`. The block reassigns `$sessionDir` only inside `if ($jsonl)` after the retry. Memory presence is never tested as a fallback trigger. |
| V3 | In the failing case the transcript and the memory store are under different project keys. | Transcript: `~\.claude\projects\C--Dropbox-whertzing-GitHub-SharedVSCode-wt-62-Sprint-0014-work-items\*.jsonl` (3 files). Memory: `~\.claude\projects\C--Dropbox-whertzing-GitHub-SharedVSCode\memory\` (9 `.md` files). The `-wt-62-` key has **no** `memory\` subdirectory. |
| V4 | The failure is silent at the call site. | The skip is logged `-Level Important -Tag 'Warning'` (`:616`) and the function returns normally. Exit code 0. The `checkpoint` skill's own Step 4 treats a skip as legitimate. |
| V5 | The roster cannot distinguish this from a legitimate skip. | Roster row records `MemorySnapshotCreated: false`, `MemoryFileCount: 0`, `MemorySkipReason: "Memory directory not found: …"`. A Codex row — which is *correctly* skipped, mode `None` — is structurally identical apart from the reason string. |
| V6 | Four Sprint 0014 ClaudeCode checkpoints lost memory; all four are the same worktree. | `SprintWorkSessionRoster-0014.jsonl`: ClaudeCode `MemorySnapshotCreated=false` × 4 (2026-08-04 12:28, 08-04 12:49, 08-05 08:12, 08-05 17:31), every one `SharedVSCode-wt-62-Sprint-0014-work-items`. |
| V7 | **This is not a blanket failure** — memory capture works for other worktrees. | Same roster: ClaudeCode `MemorySnapshotCreated=true` × 13, including `ATAP.Utilities-wt-132` (9 files), `_Planning-wt-33` (15 files), `AceCommander-wt-43` (7 files). Those worktree keys *do* have their own `memory\` folders. |
| V8 | The 37 Codex `false` rows are correct behavior, not this bug. | `Save-SprintWorkSession.ps1:522-527` sets `$memoryCopyMode = 'None'` for Codex, which has no on-disk memory store. Do not "fix" these. |

> **Correction to an earlier verbal report.** During the session that found this, it was
> initially stated that *every* sprint-worktree checkpoint would lose memory and that sprint
> memory snapshots were "empty across the board." V7 disproves that. The defect is real but
> conditional — it fires only when a worktree's project key lacks a `memory\` folder while
> the corresponding stable-repo key has one. Do not size the work off the original claim.

---

## Open question — RESOLVED 2026-08-05 (Task 14.13.a)

> **ANSWER: neither A nor B. Hypothesis C — a provisioning gap.** The `-wt-62-` project key
> **has never had a `memory\` folder**, so nothing disappeared and nothing was deleted.
> Full evidence: `ATAP.Utilities/_generated/Task-14.13/14.13.a-open-question-resolution.md`.
>
> The premise below is false, and this is my own error to correct — the 2026-08-03 "working
> 2-file store" was not a memory store at that key. The roster's `MemorySourcePath` for that
> row is
> `…\Temp\claude\C--Users-whertzing\5a480210-…\scratchpad\claude-projects-shim\c--…-wt-62-…\memory`
> — a **synthetic fixture under the session scratchpad**, seeded from the user-scope store
> (its two files are byte- and mtime-identical to `…\projects\C--Users-whertzing\memory\`).
> The four later rows resolved into the real projects tree. Two different roots were compared
> as though they were one.
>
> Corroborating: the `-wt-62-` project directory has `CreationTime = 2026-08-04 12:03` — it
> did not exist on 08-03. Hypothesis A is disproved by asymmetry: the other four Sprint 0014
> worktree keys each hold their own memory as a junction into
> `C:\Dropbox\whertzing\ATAP\AIAgentMemory\<Repo>` and 13 checkpoints captured from them.
> `~\.claude` is not under Dropbox, so discriminator 3 is inapplicable, not inconclusive.
>
> **The real defect:** `AIAgentMemory\` holds stores for `_Planning`, `AceCommander`,
> `ATAP.IAC`, and `ATAP.Utilities` — **SharedVSCode is missing**. Task 14.4's junction
> provisioning covered four of five repositories, so SharedVSCode sprint sessions write
> memory to an unprovisioned key. That is a separate defect from this one and is routed to
> `_Planning/InformationForTheFuture/SharedVSCode-memory-provisioning-gap.md`; do not absorb
> it into the `Save-SprintWorkSession` fix.
>
> **Effect on the fix:** proceed to the suggested direction below. It remains correct — a
> stable-key fallback would have captured the 9-file SharedVSCode store instead of nothing.
> The "prefer the sprint key whenever it exists" guard matters *more* than first thought,
> because the SharedVSCode stable store is stale (untouched since 2026-06-26). Backfill is
> unnecessary: nothing was lost.

### Original framing (retained for provenance — premise now known false)

There are two candidate root causes and the evidence does not yet separate them. Picking a
fix without settling this risks papering over the real problem.

**Observation that forces the question:** the `-wt-62-` project key *did* have a working
memory store earlier in this same sprint, and it disappeared.

- 2026-08-03 10:49 — checkpoint from `SharedVSCode-wt-62`, slug
  `c--Dropbox-whertzing-GitHub-SharedVSCode-wt-62-Sprint-0014-work-items`, captured
  **2 files** (`MEMORY.md` 130 B + `atap-foundation-formation.md`). Snapshot still on disk at
  `_Planning-wt-33-…\SprintWorkSessionMemorys\SprintWorkSession-0014-SharedVSCode-wt-62-…-2026-08-03-104940-3b268-380048\`.
- 2026-08-04 12:28 onward — same slug, **0 files**, directory not found.
- Those 2 files are a *different* store from the 9-file stable-key store now in use. They are
  not a subset; the content does not overlap.

So between 2026-08-03 and 2026-08-04 the sprint key's `memory\` folder ceased to exist, and
the active memory store for sessions launched in that worktree became the stable-repo key's
store.

**Hypothesis A — harness-side keying (fix is a no-op or a follow, not a repair).**
Claude Code decides where a session's memory lives and reports it in the system prompt. If
it now resolves worktrees back to a parent/stable project identity, then memory legitimately
lives at the stable key and `Save-SprintWorkSession` simply needs to follow it. Under A the
disappearance is expected behavior, not data loss.

**Hypothesis B — the store was deleted or orphaned.**
If something removed `…-wt-62-…\memory\` (cleanup script, sprint tooling, manual action,
Dropbox sync), then a real memory store was lost and following the stable key would mask an
ongoing deletion problem.

**How to settle it, cheaply:**

1. Start a Claude Code session in a worktree whose key *does* have memory
   (`ATAP.Utilities-wt-132-…`) and one in `SharedVSCode-wt-62-…`. In each, read the memory
   directory path stated in the system prompt. If the first reports its own worktree key and
   the second reports the stable key, that is asymmetric and points at B (or at a
   per-project setting difference), not a uniform harness rule.
2. Check for a `memory`-related setting in `.claude/settings.json` /
   `settings.local.json` for each worktree, and in the user-global settings.
3. Check Dropbox version history / recycle bin for
   `~\.claude\projects\C--Dropbox-whertzing-GitHub-SharedVSCode-wt-62-Sprint-0014-work-items\memory\`
   around 2026-08-03/04.
4. Grep the sprint lifecycle tooling for anything that removes a `memory` folder
   (`SprintStartAgent`, `SprintEndAgent`, worktree teardown).

Record the answer in this document before changing code.

---

## Mechanism, precisely

`Save-SprintWorkSession.ps1`, `switch ($Agent)` → `'ClaudeCode'` branch, lines ~394-440:

1. `:404` slug the CWD (lowercase drive letter; `:` `\` `_` `.` → `-`).
2. `:407-410` `$sessionDir` = that slug's project dir; find newest `*.jsonl`.
3. `:412-429` **if and only if no JSONL was found**, strip `-wt-.+$` from the CWD, reslug,
   and retry. On success reassign `$slug` and `$sessionDir`.
4. `:431-433` throw if still no JSONL.
5. `:437` `$memSrcDir` = `$sessionDir\memory` ← **the defect**. Memory inherits the
   transcript's directory unconditionally.
6. `:611-616` if `$memSrcDir` does not exist → set `$memorySkipReason`, log Important,
   continue. No failure, no distinct outcome code.

The comment at `:435-436` states the intended invariant — *"Memory lives under the slug of
the directory where Claude Code was launched … NOT under the _Planning slug"* — which is
correct as far as it goes but assumes transcript and memory always share a key. V3 shows
they do not.

---

## Reproduction

```powershell
# From the affected worktree
Set-Location 'C:\Dropbox\whertzing\GitHub\SharedVSCode-wt-62-Sprint-0014-work-items'
# …dot-source Save-SprintWorkSession per the checkpoint skill's Resolve-CheckpointFunction…
Save-SprintWorkSession -Agent ClaudeCode
```

Expected on a healthy path: `Memory files saved (N files): …`.
Actual: `Memory directory not found: …\C--…-wt-62-Sprint-0014-work-items\memory — memory copy skipped.`
and a roster row with `MemorySnapshotCreated: false`.

Confirm the precondition first:

```powershell
$p = 'C:\Users\whertzing\.claude\projects'
Get-ChildItem $p -Directory |
  ForEach-Object {
    [pscustomobject]@{
      Key       = $_.Name
      Transcripts = @(Get-ChildItem $_.FullName -Filter *.jsonl -EA SilentlyContinue).Count
      HasMemory = Test-Path (Join-Path $_.FullName 'memory')
    }
  } | Where-Object Transcripts -gt 0 | Sort-Object Key | Format-Table -AutoSize
```

Any row with `Transcripts > 0` and `HasMemory = False` is a worktree whose next checkpoint
will silently skip memory. At time of writing: 5 such keys.

---

## Suggested direction (not prescriptive — settle the open question first)

Three changes, separable. **2 and 3 are worth doing regardless of how the open question
resolves**; 1 depends on it.

**1. Decouple memory resolution from transcript resolution.** Locate `$memSrcDir`
independently: probe the sprint slug's `memory\`, and if absent probe the stable slug's
`memory\`, mirroring the existing `-wt-.+$` strip. If found at the stable key, record which
key was used so the roster shows it. Guard against the inverse surprise — a stable-key store
that is *staler* than the sprint one — by preferring the sprint key whenever it exists.

**2. Make an unexpected skip structurally distinct from a legitimate one.** Today
`MemorySkipReason` is prose and the only machine-readable signal is a boolean. Add a
discriminated outcome — e.g. `MemorySkipKind` ∈ `{ None, NotFound, Empty }` where `None`
means "this agent has no memory store" (Codex, correct) and `NotFound` means "expected a
store and did not find one" (this bug). This is the same verified-vs-asserted separation the
Stream L brief requires of `gather-content-summary`: a run that captured nothing must never
look like a run that had nothing to capture.

**3. Consider making `NotFound` loud.** For `-Agent ClaudeCode`, a missing memory store is
almost certainly wrong. Options, in increasing severity: `-Level Warning` and a summary line
in the function's return; a non-terminating error; or an opt-in `-RequireMemory` switch that
throws. Recommend at least surfacing it in the object the caller prints, so the `checkpoint`
skill's Step 4 report shows it without the operator reading PSFramework output.

**Backfill.** The four lost snapshots (V6) are recoverable if the underlying store still
exists — the stable-key store is intact. Decide whether to backfill
`SprintWorkSessionMemorys\` for those four roster entries or leave them and note the gap.
The 2026-08-03 2-file store is **not** recoverable from the live tree; its only surviving
copy is the snapshot already archived in `_Planning-wt-33-…` (see Open Question).

---

## Test seam

`src/ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell/tests/Unit/Save-SprintWorkSession.Tests.ps1`
already covers the adjacent cases and is the template to follow:

- `:208` `Context 'Bug 2 — slug fallback: stable-repo slug when sprint-worktree slug has no JSONL'`
  — the existing transcript fallback. The new case is its mirror: **JSONL present at the
  sprint slug, memory present only at the stable slug.** Add a sibling Context.
- `:258` `Context 'Task 12.29 — Claude project slug directory casing'` — already asserts
  memory is copied from the actual on-disk casing; extend rather than duplicate.
- `:636` `Context 'Task 9.32 — Codex path'` — regression guard: Codex must keep skipping
  memory with the `None` kind. Any change to skip semantics must not disturb this.

Minimum new coverage:

1. sprint key has JSONL + no `memory\`, stable key has `memory\` → memory copied, roster
   records the stable key as the source.
2. both keys have `memory\` → sprint key wins.
3. neither has `memory\` → skip recorded as `NotFound`, distinct from Codex's `None`.
4. Codex unchanged → `None`.

Run per repo convention, profiles enabled (no `-NoProfile`):

```powershell
pwsh -Command "Invoke-Pester -Path './src/ATAP.Utilities.BuildTooling.SprintLifecycle.PowerShell/tests/Unit/Save-SprintWorkSession.Tests.ps1' -Output Detailed"
```

---

## Definition of done

Per the workspace working principles, "done" is deploy-state, not build-state.

- [x] Open question resolved and the answer recorded in this file. (2026-08-05, Task 14.13.a
      — Hypothesis C, provisioning gap; no deletion. Evidence
      `ATAP.Utilities/_generated/Task-14.13/14.13.a-open-question-resolution.md`.)
- [x] Fix implemented in the **sprint** worktree `ATAP.Utilities-wt-132-Sprint-0014-work-items`
      (never the stable root).
- [x] New Pester coverage green, existing Contexts still green. (33/33 and 17/17; full suite +15 passing, +0 new failures.)
- [x] Adversarial pass documented: what near-variant re-breaks it? At minimum consider —
      stable key also missing `memory\`; both keys present but stable is stale; a repo whose
      path legitimately contains `-wt-` ; casing differences between the two keys (`C--`
      vs `c--` both occur on this machine — see V3); a worktree that is not a sprint worktree.
- [x] Module version bumped and promoted through the tier ladder, then **installed to the
      consuming scope** — ProGet feed versions are immutable, so a fix that is only built is
      not shipped. Use the `build-deploy-module` skill.
- [x] Verified end-to-end by running `/checkpoint` from
      `SharedVSCode-wt-62-Sprint-0014-work-items` and confirming a non-zero
      `MemoryFileCount` in a new `SprintWorkSessionRoster-0014.jsonl` row — not by reading
      the source.
- [x] Backfill decision made and recorded. (User directed a backfill from the stable-key store over a recommendation to record the gap; 5 folders backfilled, each with a `_BACKFILL-PROVENANCE.md` marker.)
- [x] Evidence written under `_generated/` per SC-0033. (`_generated/Task-14.13/` and `_generated/Task-14.14/`.)

---

## Working notes for whoever picks this up

- Resolve `Save-SprintWorkSession` with the `Resolve-CheckpointFunction` search pattern from
  the `checkpoint` skill. **Do not hard-code a BuildTooling module folder** — a pinned
  `…BuildTooling.PowerShell\public\` path broke `/checkpoint` outright on 2026-07-24 after
  the SprintLifecycle extraction.
- The `checkpoint` skill itself needs no change for this fix; it only reports what the
  function returns. If change 2 lands, the skill's Step 4 wording may be worth revisiting so
  a `NotFound` is not reported to the user as a benign skip.
- Everything in "Verified facts" was established read-only. No remediation has been
  attempted; the four affected roster rows are untouched.
