# Handoff — Task 15.162.e D09 Fody failure, root-cause investigation

**Date:** 2026-08-19
**Repo / worktree:** ATAP.Utilities, `137-Sprint-0015-work-items`
**Status:** investigation complete; **superseded by replanning**. No remediation was
implemented. No claims held (see section 10).
**Supersedes the root-cause section of:**
`_Planning/InformationForTheFuture/Sprint0015/StreamP/Task-15.162.e-D09-Fody-Evidence-Review.md`
(operator-approved 2026-08-18)
**Full evidence:** `_generated/Sprint0015/StreamP/Task15.162.e/root-cause-2026-08-18/findings.md`
(NOTE: `_generated/` is deleted at sprint end — copy anything durable out before then.)

---

## 1. What the approved record says, and what is wrong with it

The approved review concluded:

> "The proven root-cause class is shared-intermediate/output contention followed by
> incomplete incremental recovery from Fody's failed rewrite. The exact process that
> briefly owned the original PDB cannot be attributed after its handle closed."

**The contention half is falsified. The owner is now attributed.**

The probe that "passed" in the original investigation used task-owned intermediate paths.
That changed two variables at once: it removed MSBuild node contention **and** it moved
`obj` out of the Dropbox sync root. Only the second one mattered.

The recovery half of the original record stands: an ordinary incremental build does
preserve the zero-byte output, and `Rebuild` clears it.

## 2. Actual root cause

**`Dropbox.exe` transiently opens each freshly-written `obj\<cfg>\<tfm>\*.pdb` inside the
sync root, and Fody/Mono.Cecil writes the woven assembly non-atomically.**

`ModuleDefinition.Write(fileName)` opens the target **DLL** with `FileMode.Create` —
truncating it to zero bytes — and only *then* calls `GetSymbolWriter`, which opens the
**PDB** via `File.Open(path, Create, ReadWrite)`, i.e. `FileShare.None`, with no retry.
Any reader holding that PDB for a few milliseconds therefore fails the build *after* the
DLL has already been destroyed.

The worktree lives at `C:\Dropbox\whertzing\GitHub\...`. `obj` is not marked
`com.dropbox.ignored`; it carries `com.dropbox.attrs`, confirming Dropbox tracks build
intermediates.

## 3. Evidence, separated from assertion

| # | Claim | Status | Evidence |
| - | ----- | ------ | -------- |
| 1 | Reproduces on a clean full build | VERIFIED | `dotnet build ATAP.Utilities.Production.slnf -c Release -t:Rebuild` produced 8 Fody errors across 4 distinct locked PDBs |
| 2 | Each violation leaves exactly one 0-byte DLL at the matching path | VERIFIED | 4 locked PDBs produced 4 zero-byte `obj\Release\<tfm>\*.dll`, 1:1 by path; `bin` had none |
| 3 | Locked file is the project's own `obj` PDB, never `Fody.dll` | VERIFIED | every failure names `...\obj\Release\<tfm>\<Project>.pdb`; stack is `PortablePdbWriterProvider.GetSymbolWriter` |
| 4 | DLL is truncated before the PDB is opened | VERIFIED (mechanism) | Cecil call order plus the 1:1 zero-byte DLLs in claim 2 |
| 5 | `Dropbox.exe` holds those PDBs during builds | VERIFIED | Restart Manager `RmGetList` named `Dropbox` PID 32580 holding `ATAP.Utilities.String.pdb` |
| 6 | Moving `obj`/`bin` out of the Dropbox root eliminates it | VERIFIED | interleaved A/B, 3 rounds x 20 rebuilds per arm, same session: **in-Dropbox 9/60, out-of-Dropbox 0/60**. Earlier uninstrumented runs: in-Dropbox 4/60, out-of-Dropbox 0/40 |
| 7 | NOT shared-intermediate contention between MSBuild nodes | VERIFIED (falsifies prior finding) | Arm B ran the identical multi-TFM parallel graph at identical node count with 0 failures; per-TFM `obj` paths are disjoint; no duplicate project entries in `.sln`/`.slnf` |
| 8 | ATAPBUILD002 fires on the *next* build, not the failing one | VERIFIED | 8 Fody errors and 0 ATAPBUILD002 in the same log — `VerifyNonEmptyOutputAssembly` is `AfterTargets="Build"` and never runs when Fody errors |
| 9 | `com.dropbox.ignored` on `obj` is a sufficient fix | **UNPROVEN** | one 30-iteration probe gave 1/30 and Dropbox was still observed holding the PDB. Needs a repo-wide test before being relied on |
| 10 | Avast is a second candidate reader | **ASSERTED, UNVERIFIED** | Defender realtime is off; Avast is the active AV (`aswidsagent`, `AvastSvc` running). Never observed holding a PDB; disabling AV was out of scope |

### Methodology warning for whoever continues this

The Restart Manager probe (`Find-PdbHolder.ps1`) **is intrusive**. `RmRegisterResources`
perturbs the file and drove the observed failure rate from roughly 10% to roughly 90%.
Use it to *name* a holder; never use it to *measure* a rate. Every rate quoted above comes
from an uninstrumented run.

## 4. Secondary corrections found

- `Directory.Build.targets:236` — the ATAPBUILD002 message blames "the C# language server
  holds a lock on Fody.dll or MethodBoundaryAspect.dll". That is wrong in both the file
  named and the process blamed. It should name a transient reader of the project's own
  `obj` PDB, and the remedy is `-t:Rebuild` for the affected project.
- The guard is not self-healing: it reports the 0-byte assembly but leaves it on disk, so
  an ordinary incremental build preserves the corrupt output indefinitely.

## 5. Blast radius (input to replanning)

200 `FodyWeavers.xml` files enable the MethodBoundaryAspect weaver. Only **16** projects
contain an uncommented `[ETWLogAttribute]` — the repo's only `OnMethodBoundaryAspect`
subclass. At 3 TFMs a full build performs about 600 Cecil rewrite cycles, roughly 550 of
which weave nothing yet still open the truncate-then-open window.

The 16 projects that actually need Fody:

```
samples/ATAP.Console.Console01, samples/ATAP.Console.Console03, samples/ATAP.Service.Service01,
src/ATAP.Services.ConsoleMonitor, src/ATAP.Services.ConsoleSink, src/ATAP.Services.ConsoleSource,
src/ATAP.Services.FileSystemWatchers, src/ATAP.Services.GenerateProgram,
src/ATAP.Services.TcpWithResilience, src/ATAP.Services.Timers,
src/ATAP.Utilities.Collection.Extensions,
src/ATAP.Utilities.ComputerInventory/Hardware/Extensions,
src/ATAP.Utilities.Configuration/Extensions, src/ATAP.Utilities.GenerateProgram,
src/ATAP.Utilities.GenericHost.Extensions, src/ATAP.Utilities.Reactive.Extensions
```

## 6. Candidate remediations — NOT implemented, for replanning to rank

1. **Stop Dropbox syncing build intermediates.** Either move the GitHub worktrees out of
   the Dropbox root (proven, claim 6) or set `com.dropbox.ignored` on every `obj`/`bin`
   (unproven, claim 9 — test repo-wide first). This is the only change that addresses the
   actual cause.
2. **Restrict Fody to the 16 projects listed above** instead of injecting
   `MethodBoundaryAspect.Fody` from `Directory.Build.targets` into all 200. Cuts exposure
   by roughly 90% and removes about 550 pointless rewrites per full build.
3. **Correct the ATAPBUILD002 message text.**
4. **Make the guard self-healing** — delete the 0-byte assembly on detection so the next
   build regenerates it.

Items 2 through 4 reduce or contain the damage; only item 1 removes the trigger.

## 7. Unrelated blockers surfaced while building the slnf

Both are pre-existing and were neither caused by nor dependent on the Fody issue.

- **`ATAP.Utilities.Production.slnf` does not build at all: 2736 errors and 187 warnings
  across 22 projects, none Fody-related.** Dominant clusters: CS0305 (4074 occurrences —
  `G*<TValue>` arity in `ATAP.Utilities.GenerateProgram`), CS0246/CS0234 (missing NUnit,
  FluentAssertions, and `ATAP.Utilities.Philote` references in several test projects),
  CS0738 interface return-type mismatches, SYSLIB0011 escalated to error in
  `ATAP.Utilities.ConcurrentObservableCollections`, and NETSDK1005 (no net10.0 target in
  `ATAP.Utilities.Secrets.BitwardenSecretsManager.PackageSmoke.Tests`).
  **Any plan that treats the Production slnf as green needs to account for this first.**
- **`ValidateToolchainBaseline` races itself.** It runs `dotnet workload list` concurrently
  from parallel project builds and collides on
  `~\.dotnet\sdk-advertising\10.0.400\...\WorkloadManifest.json`, producing ATAPTOOLCHAIN013
  and MSB3073. Same bug class as the Fody one: an unsynchronised shared file.

## 8. Actions taken in this session

**Investigative only. No source, package, lock, analyzer, or policy file was modified.**

- Ran `ATAP.Utilities.Production.slnf` builds repeatedly: one incremental, one full
  `-t:Rebuild`, plus roughly 220 single-project rebuild iterations across the A/B arms.
- Built and ran two throwaway instruments (a Restart Manager holder probe and an
  interleaved A/B harness), both archived under `_generated/.../root-cause-2026-08-18/`.
- Temporarily set and then removed a `com.dropbox.ignored` ADS on
  `src/ATAP.Utilities.String/obj` for one experiment. **Removed; verified gone.**
- Temporarily relocated `src/ATAP.Utilities.String/{obj,bin}` to `D:\Temp\fodytest` for
  the out-of-Dropbox arm. **Restored; scratch directory deleted.**
- Repaired all 5 zero-byte DLLs the reproductions created, by rebuilding the 5 owning
  projects.
- Shut down the MSBuild and VB/C# compiler servers; confirmed no `dotnet` or `MSBuild`
  handles remain inside the worktree.

## 9. State left behind

- `git status` shows **417 changed files, identical to session start.** No net working-tree
  change.
- Zero-byte DLLs repo-wide: **0**.
- Branch `137-Sprint-0015-work-items`. Nothing staged, nothing committed, no PR.
- New untracked evidence (gitignored, sprint-scoped):
  `_generated/Sprint0015/StreamP/Task15.162.e/root-cause-2026-08-18/`
- This handoff file is the durable record; `_generated/` is not.

## 10. Claims released

No formal claim was ever taken: `agent-swarm-dispatch` was not invoked, no subagent was
dispatched, and no lease or reservation registry entry exists naming this session. The
only exclusive resource held was the worktree's build output, and that is released — build
servers are down and the tree is clean. **The worktree is free for the replanning agent.**
