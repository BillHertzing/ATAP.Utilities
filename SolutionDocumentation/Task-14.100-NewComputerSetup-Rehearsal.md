# Task 14.100 - New Computer Setup Rehearsal on ncat040

## Objective

Rehearse the revised [NewComputerSetup.md](NewComputerSetup.md) procedure on `ncat040`
and produce metadata-only evidence that the resulting host matches the approved UTAT
baseline. This work carries forward Sprint 0013 Tasks 13.65 and 13.65.e.

The rehearsal is complete only when every applicable runbook step has a recorded result,
every difference from the approved baseline has an explicit disposition, and another
developer can audit the evidence without needing access to a secret value.

## Scope boundary

Task 14.100 validates the setup procedure and proves parity. Task 14.108 separately owns
permanent onboarding details for `ncat040`, including ATAP.IAC host documentation, DHCP
reservations, temporary-password rotation, and final host-parity completion. Evidence may
support both tasks, but neither task is closed merely because the other one is complete.

Do not write passwords, tokens, connection strings, private keys, recovery codes, or vault
exports into source, logs, screenshots, or evidence. Refer to credentials only by
SecretName. The current WinRM credential SecretName is `SvcAnsibleAdmin.ncat040`; the
current local account name is `ansibleAdmin`.

## Evidence location

Write generated rehearsal output under:

```text
_generated/Sprint0014/StreamK/Task-14.100/
```

Use `InformationForTheFuture/` in the `_Planning` sprint worktree for any finding that is
an input to future work rather than evidence of this completed rehearsal.

## Stop conditions

Stop and request senior-developer direction when any of the following occurs:

- A step would erase or reset an existing disk, database, repository, vault item, or backup.
- A required secret does not exist or cannot be resolved by its SecretName.
- The runbook conflicts with the observed host state or the approved UTAT baseline.
- A change would expose WinRM, SQL Server, ProGet, BuildMaster, or another service beyond
  the private network or its documented listener boundary.
- A parity difference has no documented owner or disposition.
- An unexpected file or repository change appears outside the assigned work scope.

## Task 1 - Confirm authorization and rehearsal boundaries

- [ ] Confirm that `ncat040` is the authorized clean/reset host for the Task 14.100 rehearsal.
- [ ] Confirm that the approved comparison hosts are `utat022` and `utat01`.
- [ ] Record the current sprint, task ID, operator, host name, and start time in the evidence
  summary.
- [ ] Confirm that generated evidence will use the Task 14.100 evidence location.
- [ ] Confirm that no destructive reset is required before continuing. If a reset is required,
  stop and obtain explicit approval.

Deliverable: `01-rehearsal-boundary.md` containing the confirmations and any approved
limitations.

## Task 2 - Capture the starting state

- [ ] Record the Windows edition, version, build, installation date, and computer name.
- [ ] Record CPU, installed memory, firmware version, disk model, disk capacity, and disk
  health metadata.
- [ ] Record network-adapter names, link state, DHCP/static mode, and assigned addresses.
- [ ] Record the current PowerShell 7, Git, .NET SDK, VS Code, Python, `bw`, and `bws`
  versions when installed.
- [ ] Record installed Windows features and service names required by the setup guide.
- [ ] Record current WinRM listeners and the local WinRM service state without recording
  credentials.
- [ ] Record current repository and worktree paths without modifying them.
- [ ] Mark every unavailable data point as `Not installed`, `Not configured`, or `Blocked`,
  rather than omitting it.

Deliverable: `02-starting-state.json` plus a short secret-safe summary in
`02-starting-state.md`.

## Task 3 - Validate remote administration

- [ ] From `utat022`, confirm that `ncat040` is present in
  `WSMan:\localhost\Client\TrustedHosts` without replacing existing entries.
- [ ] Resolve `SvcAnsibleAdmin.ncat040` through the approved Bitwarden helper without
  displaying or persisting its value.
- [ ] Validate authenticated WinRM connectivity as `ncat040\ansibleAdmin` using Negotiate
  authentication.
- [ ] Run a bounded remote identity probe that returns only the remote computer name,
  account name, PowerShell version, and OS version.
- [ ] Confirm the same TrustedHosts action is recorded for `utat01` in the parity journal.
- [ ] Record only the connection result, protocol, account identifier, timestamp, and remote
  metadata.

Deliverable: `03-winrm-validation.json` and the parity-journal entry identifier.

## Task 4 - Execute the setup guide in order

- [ ] Work through [NewComputerSetup.md](NewComputerSetup.md) from the first applicable
  step to the final acceptance step.
- [ ] For each heading, record one status: `Pass`, `Fail`, `Not applicable`, `Deferred`, or
  `Blocked`.
- [ ] Record the exact command or manual action used for each `Pass` or `Fail` result.
- [ ] Record the reason and approving owner for each `Not applicable` or `Deferred` result.
- [ ] Stop at any runbook approval gate and obtain the required approval before continuing.
- [ ] Do not silently substitute a different tool, package source, service identity, port,
  path, or configuration mechanism.
- [ ] Record unclear, incorrect, or non-idempotent runbook instructions as documentation
  findings.

Deliverable: `04-runbook-step-results.md`, with one result row for every applicable
runbook heading.

## Task 5 - Establish the Windows and tool baseline

- [ ] Apply all approved Windows updates and record the final build and pending-reboot state.
- [ ] Confirm the computer name, timezone, network profile, and required Windows features.
- [ ] Validate memory and hardware health using the procedure and acceptance threshold in
  the setup guide.
- [ ] Install or update the required core tools using their documented package owner.
- [ ] Confirm required executables resolve from a fresh PowerShell 7 session.
- [ ] Confirm the installed versions satisfy the runbook and approved UTAT baseline.
- [ ] Record any intentional version difference with its reason, owner, and follow-up action.

Deliverable: `05-windows-and-tools-parity.json`.

## Task 6 - Establish the ATAP development baseline

- [ ] Confirm Dropbox is synchronized before creating or changing repository worktrees.
- [ ] Confirm the five ATAP repositories exist at their approved stable or sprint-worktree
  paths as specified by the current workspace overview.
- [ ] Confirm each repository is on the expected branch and has the expected remote URL.
- [ ] Confirm Git safe-directory entries are no broader than the documented repository
  paths.
- [ ] Render PowerShell profiles from the current canonical ATAP.IAC source.
- [ ] Open a fresh PowerShell 7 session and verify the actual profile paths loaded.
- [ ] Confirm required ATAP modules autoload and that `$global:settings` resolves through
  the approved host/user configuration path.
- [ ] Confirm no repository-local `.vscode/settings.json` was introduced.

Deliverable: `06-development-baseline.json`.

## Task 7 - Validate secrets and service-account boundaries

- [ ] Confirm personal Password Manager access and machine Secrets Manager access remain
  separate.
- [ ] Confirm automation uses `bws` and the approved `Get-SecretATAP` path rather than a
  personal `BW_SESSION`.
- [ ] Confirm each required service account exists, is enabled only where required, and has
  the documented local rights.
- [ ] Confirm evidence refers to each credential only by SecretName.
- [ ] Confirm no secret value appears in generated evidence or repository changes.
- [ ] Leave password rotation and permanent `ncat040` secret disposition under Task 14.108
  unless separately authorized.

Deliverable: `07-secret-boundary-validation.md` containing pass/fail metadata only.

## Task 8 - Validate database and hosted-service parity

- [ ] Confirm the required SQL Server instances exist with the documented names, editions,
  services, and startup modes.
- [ ] Confirm required databases and migration heads using metadata-only queries.
- [ ] Confirm SQL connection material is resolved by SecretName and is absent from evidence.
- [ ] Validate ProGet and BuildMaster only when the approved UTAT baseline assigns those
  placed services to `ncat040`.
- [ ] Confirm each hosted service uses its documented port and listener boundary.
- [ ] Confirm no non-loopback or non-private firewall exposure was introduced.
- [ ] Record `Not applicable` with baseline evidence when a hosted service is intentionally
  not placed on `ncat040`.

Deliverable: `08-database-and-services-parity.json`.

## Task 9 - Compare ncat040 with the approved UTAT baseline

- [ ] Build a parity matrix with one row for every baseline item checked by the setup guide.
- [ ] Record the `ncat040`, `utat022`, and `utat01` metadata values for each row.
- [ ] Classify each row as `Match`, `Approved difference`, `Defect`, or `Not applicable`.
- [ ] Give every `Approved difference` its rationale and approving owner.
- [ ] Give every `Defect` an owner, corrective action, and target task.
- [ ] Re-run affected checks after corrections and retain both the original result and the
  final result.
- [ ] Confirm no unresolved defect is represented as parity.

Deliverable: `09-utat-baseline-parity.csv` and `09-utat-baseline-parity-summary.md`.

## Task 10 - Record parity changes

- [ ] Add a secret-safe parity-journal entry before each state-changing action on `ncat040`.
- [ ] Include category, item, old state, new state, peer host, peer action, and reason.
- [ ] Add corresponding peer actions for `utat022` or `utat01` when the change must be
  repeated there.
- [ ] Do not acknowledge a peer action until it has actually been applied and verified on
  that peer.
- [ ] Record the journal entry identifiers in the rehearsal summary.

Deliverable: `10-parity-journal-index.json` containing identifiers and statuses, not secret
values.

## Task 11 - Perform the final acceptance pass

- [ ] Reboot `ncat040` when required by the setup guide and confirm it returns to the expected
  state.
- [ ] Re-run the bounded WinRM identity probe from `utat022`.
- [ ] Re-run the tool, profile, repository, service, database, listener, and firewall checks.
- [ ] Confirm all applicable runbook steps are `Pass` or have an explicitly approved
  disposition.
- [ ] Confirm the parity matrix contains no unowned defect.
- [ ] Scan all Task 14.100 evidence for likely secret patterns and remove any exposed value
  before publishing.
- [ ] Record every acceptance claim beside the command or artifact that proves it.

Deliverable: `11-final-acceptance.md` and `11-final-acceptance.json`.

## Task 12 - Prepare the coordinator handoff

- [ ] Summarize what succeeded, what failed, and what was intentionally not applicable.
- [ ] List every change proposed for [NewComputerSetup.md](NewComputerSetup.md), including
  the observed failure mode and the recommended correction.
- [ ] List all remaining Task 14.108 work separately from Task 14.100 findings.
- [ ] Provide links to the evidence index, parity matrix, final acceptance result, and parity
  journal identifiers.
- [ ] Mark every statement as `Verified` or `Asserted, unverified`.
- [ ] Ask the senior developer or coordinator to review the evidence before changing the
  sprint board status.

Deliverable: `12-coordinator-handoff.md`.

## Coordinator-only closure steps

- [ ] Review the evidence for completeness and absence of secrets.
- [ ] Confirm the rehearsal used the current revised setup guide.
- [ ] Confirm the parity comparison used the approved UTAT baseline.
- [ ] Confirm all defects and approved differences have owners and dispositions.
- [ ] Update the active sprint board and its HTML copy together.
- [ ] Add concrete completion evidence to `Tasks.Accomplished`.
- [ ] Add reusable procedure changes to `Tasks.ProceduralDetails`.
- [ ] Close Task 14.100 only after the metadata-only evidence is published and reviewable.

## Definition of done

Task 14.100 is done when the revised setup guide has been rehearsed on `ncat040`, all
applicable steps have auditable results, the final parity matrix proves conformance with
the approved UTAT baseline or records approved differences, all remaining defects have
owners, and metadata-only evidence is published without secrets. A successful WinRM probe,
tool installation, build, or individual service check alone is not sufficient to close the
task.
