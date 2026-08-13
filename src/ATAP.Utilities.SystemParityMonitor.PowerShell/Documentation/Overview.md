# SystemParityMonitor — Overview

The SystemParityMonitor module keeps a pair of hosts in declared parity. It was built
in Sprint 0012 (Task 12.38, as ATAP.IAC `Windows\Parity`) and relocated to
ATAP.Utilities in Task 12.46.

## Concepts

- **Parity journal** — an append-only JSONL journal per host under the state root
  (`C:\ProgramData\ATAP\ParityState`). `Add-ParityChangeEntry` records each intentional
  configuration change (the "declared" changes).
- **Acknowledgements** — `Get-PeerPendingChanges` lists peer journal entries the local
  host has not yet applied; `Confirm-ParityChangeApplied` records an ack once the change
  is mirrored locally.
- **Audit snapshots** — `Invoke-ParityAudit` captures a snapshot of the host's
  configuration surfaces (per the internal surface map) into the state root.
- **SQL topology surfaces** — snapshots include named engine instances, service state
  and identity, version, logins, server roles and permissions, Agent jobs, endpoints,
  fixed TCP configuration, default directories, and physical-file conformance to
  `C:\LocalDBs\<INSTANCE_NAME>\{Data,Log,Backup}\`.
- **Package-manager surfaces** — Chocolatey is machine-scoped. In next-release source,
  pip, npm, and NuGet global tools are read only from configured, identity-explicit
  `PipPath`, `NpmPrefix`, and `NuGetToolPath` values. The collector does not substitute
  the scheduled account's profile. Missing configuration produces an explicit status,
  not an empty inventory that can appear clean.
- **Package ownership conflicts** — package names are normalized case-insensitively
  within each configured identity. If one identity has more than one owning manager
  for a normalized name, the audit emits a host-and-identity-qualified
  `PackageManagerConflict` row beginning
  `ACTION REQUIRED`. Host qualification intentionally keeps the warning in the drift
  report even when both hosts share the same conflict; an operator must select one
  manager and remove the duplicate installation.
- **Drift comparison** — `Compare-ParityAudits` compares the two hosts' latest
  snapshots and classifies every difference as **declared** (journaled), **whitelisted**
  (expected per-host differences), or **undeclared drift** (the actionable class), and
  flags **stale** snapshots older than the expected cadence.
- **Coverage failures** — next-release source requires minimum category counts during
  audit and comparison. A wholly absent category is `Missing`; a nonzero category
  below its minimum is `Thin`. Audit findings are written into the diagnostic snapshot
  before the command throws, so incomplete collection cannot be reported as clean.

## Coverage boundary

The snapshot contains only the surfaces its collectors emit. In particular, the
`PowerShell/PSVersion` row is the PowerShell engine version; installed ATAP PowerShell
module names and versions are **not** collected. A green comparison is not evidence of
module-version parity. User-scoped package parity is also meaningful only for identities
whose explicit profile paths were configured and readable.

### Host IPv6 reachability for Inedo services (Sprint 0013)

A host-pair parity concern that is invisible to service configuration: both hosts must be
able to reach BuildMaster (`50017`) and ProGet (`50000`) at **every address their own
hostname resolves to**, IPv4 and IPv6 alike.

On `utat01` in Sprint 0013, the hostname resolved to four global DHCPv6 addresses on the
Wi-Fi adapter ahead of its IPv4 address, and those addresses were **dead** — `ping -6`
against the host's own address returned *General failure* at 100% loss. Every client
resolving `utat01` tried a dead address first and hung for 30 seconds, which presented as
a broken BuildMaster.

Two things this is **not**, both of which have already misled a diagnosis here:

- **Not a listener misconfiguration.** `netstat -ano -p tcpv6` shows `[::]:50017` and
  `[::]:50000` listening; IPv6 loopback connects in single-digit milliseconds. Both
  services already bind all IPv4 and IPv6 addresses. A conclusion of "IPv4-only" usually
  comes from `netstat -ano -p tcp`, which prints only the IPv4 table — the `-p` argument
  is a protocol-family filter, not evidence of the bind.
- **Not a firewall rule.** On this host the Private and Public profiles are OFF and no
  inbound rule exists for either port.

**Parity actions.** Treat per-host IPv6 address health as an auditable surface:

- Run the hostname-reachability sweep in `NewComputerSetup.md` §9.10a on each host, and
  compare results between the pair — one host reaching its services by hostname while the
  other times out is exactly the undeclared drift this module exists to surface.
- The remedy is host networking (routable DHCPv6, or disabling/de-prioritising IPv6 on the
  adapter), never an edit to `BuildMaster.config`, `ProGet.config`, or
  `ServicePlacementMap`. Changing the placement map also rewrites the host-suffixed admin
  SecretName and breaks credential resolution.
- Journal whichever remedy is applied with `Add-ParityChangeEntry` before applying it on
  the peer, so the second host records a declared change.
- This is unresolved on `utat01` as of 2026-07-27 and must be checked on `utat022` when it
  returns; the earlier note that `utat022` ports 50000/50017/5985 were unreachable may
  share this root cause.

### Host-local AI agent memory junctions (Sprint 0013)

AI agent memory for the ATAP repositories is stored under Dropbox at
`C:\Dropbox\whertzing\ATAP\AIAgentMemory\<RepoName>\`, deliberately outside every git
repository, so it survives sprint end and reaches every host through Dropbox sync.

Each host reaches that store through **NTFS junctions** created under
`%USERPROFILE%\.claude\projects\<slug>\memory`. Two junctions are required per repository,
because Claude Code and the checkpoint tooling resolve different slugs:

| Junction slug source | Consumer |
| --- | --- |
| Main repo path (`git rev-parse --git-common-dir`) | Claude Code reads and writes memory here |
| Sprint worktree path (transcript slug) | `Save-SprintWorkSession` reads memory here |

These junctions are **host-local configuration and are in scope for parity**. The Dropbox
target syncs automatically; the junctions do not, so a second host has the memory content
but no path to it until its own junctions are created. Treat a missing junction as a
declarable configuration change:

- Journal junction creation with `Add-ParityChangeEntry` so the peer host sees it as a
  declared change rather than undeclared drift.
- The worktree-slug junction is **sprint-scoped** and must be recreated for each new sprint
  worktree. A missing one is silent: `Save-SprintWorkSession` reports
  `MemorySnapshotCreated: false` with reason "Memory directory not found" and still exits
  successfully, so checkpoints appear to succeed while archiving zero memory files.
- Directory junctions do not require elevation.

Known hazard: because the target is Dropbox-synced, two hosts writing memory concurrently
can produce "conflicted copy" files, which an agent would read as additional memories. This
is accepted deliberately — the files are small and infrequently written — but a conflicted
copy appearing in an audit snapshot is a legitimate finding, not noise.

## Scheduled operation

`scripts\Register-ParityScheduledTasks.ps1` registers local Task Scheduler entries
for the host role:

1. `ATAP-ParityAudit` -> `Invoke-ParityScheduledAuditTask.ps1` — token-free local
   snapshot; metadata-only result JSON under `<StateRoot>\TaskResults` records
   `SecretAccessRequired = false`.
2. `ATAP-ParityCompare` -> `Invoke-ParityScheduledCompareTask.ps1` — primary-host
   comparison against the peer's state share (default `\\utat01\ParityState`). Register
   this only on the primary host (`TaskSet AuditAndCompare`).

Both wrappers import the module from this folder's parent by relative path and use the
shared `ParityScheduledTask.Common.ps1` event-reporting helper. Scheduled execution
requires no secret-vault token or credential directory and performs no PowerShell
remoting: each host writes its own snapshots locally, and `utat022` reads the
peer snapshot share during compare. Tasks default to `SvcParityAudit` with `S4U`; use
`-LogonType Password -Credential <PSCredential>` for the primary compare task when SMB
peer-share access requires reusable service-account credentials. When an administrator
registers an S4U task for a different identity, Task Scheduler also requires that
identity's credential during registration even though the saved principal remains S4U
and does not store the password. Version `0.1.3` supplies that registration credential
while retaining the S4U/Limited saved principal. Re-register tasks when the module's
on-disk location changes.

For an elevation-broker action update, `SvcAnsibleAdmin` has exactly one native Task
Scheduler permission: `TASK_CHANGE` (`0x2`) on the existing
`\ATAP\ATAP-ParityAudit` task, per host. It has no grant on the `\ATAP` folder, any
other task, task execution, deletion, ownership, or task-security management. A
folder-level `RegisterTaskDefinition` implementation cannot use this narrow task-only
right; use a direct action-only task-update implementation instead. Password-logon
registration on `utat022` remains separately subject to its in-memory credential
resolution boundary.

The `0.1.1` package installed on both live hosts omitted `scripts\` and
`Documentation\`; `scripts\` was copied manually as a temporary Task 12.38.e recovery.
Version `0.1.2` stages both folders into the package. SC-0266 owns the incomplete
Windows 10 WinRM `PSModulePath` plus a PowerShell 7 endpoint.

The resilience work formerly described here as unreleased `0.1.4` is historical source
context. Version `0.1.10` is the deployed baseline on both hosts; its scheduled actions
point to the installed immutable module root and carry the package-manager profile
configuration path. It retains the token-free behavior introduced in `0.1.8`: it removes
the BWS probe and records `SecretAccessRequired = false`; `SvcParityAudit` must not
receive a BWS token or credential directory. Source version `0.1.12` is a later release
candidate and is not a claim about the installed tasks.

Current next-release source adds resilience for the associated Windows 10 surface:
when `Get-SmbShare` is unavailable, audit collection falls back to `Win32_Share`.
Comparison also treats an absent whitelist or journal as empty and preserves the UTC
instant of deserialized snapshots during freshness calculation.

Cadence restarts as `Daily` only after SQL and package collection is trustworthy on both
hosts, and relaxes to `BiWeekly` only after a verified clean month. The earlier blind
period does not count. The compare wrapper passes the expected cadence and
`1.5` stale multiplier into `Compare-ParityAudits`, so stale snapshots are reported as
their own drift-report line.

The deployed wrappers maintain failure state and implement the D-6 Windows Application-log
contract for source `ATAP.SystemParityMonitor`: event `12380` or `12381` on the second
consecutive audit or
compare failure, and warning event `12382` immediately when comparison finds stale
snapshots or missing/thin required coverage. Event-source registration on both hosts and
forwarding into SEQ remain independently unverified; no paging claim follows from the
presence of the deployed wrapper or source code alone.

## Related documentation

- Installation, platform prerequisites, live-registration procedure, and the
  troubleshooting record: `Documentation\InstallationAndTroubleshooting.md`.
- Functional area: Environment / Workstation Setup — START HERE
  `SolutionDocumentation\NewComputerSetup.md`; see also
  `SolutionDocumentation\ConfigRootKeys-and-HostSettings.md` and
  `SolutionDocumentation\IAC-Windows-Scripts-Migration.md`.
