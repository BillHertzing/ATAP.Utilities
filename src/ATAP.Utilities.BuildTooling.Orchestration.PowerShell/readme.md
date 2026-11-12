# PowerShell coordination module

Bounded existing-task coordination with Windows-account custody, immutable requests,
prepared publication and lossless export. Source release candidate 0.1.16 adds a
held-by-default resident launcher and a disabled same-user logon registrar.

Start with [Producer-v1](Documentation/Producer-v1.md) for the actual submission,
drain, custody and root-only consuming pilot procedure. The semantic contract is
[Coordination-v1](Documentation/Coordination-v1.md); configuration vocabulary is
[Configuration-v1](Documentation/Configuration-v1.md).

Source/disposable test success does not establish installed or live-board acceptance.

## Resident launcher and disabled logon registration

- [Resident host](Resources/Resident/Invoke-CoordClerkResident.ps1)
- [Startup descriptor schema](Resources/Resident/ResidentStartup.schema.json)
- [Disabled logon registrar](Resources/Resident/Register-CoordClerkLogonTask.ps1)

The resource scripts are installed package content, not new exported producer APIs.
Run the installed host with profiled PowerShell `-File`, `-BindingPath` and the
independently approved `-ExpectedBindingSha256`. A missing, invalid or Held
descriptor returns Held before clerk import, custody reads or recovery writes.
No descriptor or task is created by importing this module.

An Active descriptor requires the actual launching Windows SID, current admitted
Coordinator holder/session, resource/lineage/generation, configured state/custody
paths, exact signed AllUsers module and host hashes, and a separately authorized
activation/exclusion reference and RFC1123 GMT interval. References configure the
approved startup; they do not create actor, custody, package or replica authority.
All input paths must be ordinary local paths. Existing profiled settings must
already be valid; there is no private-source/configuration fallback.

The host takes a separate pre-created lifetime lease, calls the installed public
`Invoke-CoordClerk` sequentially, and waits two seconds between drains. It never
keeps producer/board leases during idle waits. A stop marker or borrowed token is
observed between drains; it does not cancel an in-flight operation or impose a
hard I/O deadline. Failed admission, changed descriptor/epoch or recovery outcome
holds the host without automatic retry. Preserve journals and reconcile an unclean
termination before an admitted restart. The returned receipt/JSON reports host
status and the last drain separately; route it through approved operational logging.

The registrar accepts only a Held, pinned installed descriptor. Its `-WhatIf`
returns a proposal without querying/registering tasks. Explicit registration
creates `\ATAP\Orchestration\CoordClerkResident` **disabled**, AtLogOn for the
current user's SID with interactive logon, Limited privilege and IgnoreNew. It
refuses existing tasks and never enables, starts, grants rights or substitutes a
service identity. The action uses a hidden, noninteractive profiled PowerShell.

Current permission covers implementation/release/install, not actual registration
or activation. A later activation packet must bind new descriptor bytes and the
task action's corresponding digest, current custody/package/actor admission and
writer/replica exclusion. Do not edit installed files, reuse consumed approvals,
or infer live admission from a successful installation. The primary coordinator
chooses assignments; workers submit authorized requests or use its relay. The
resident processes admitted requests and does not allocate or message chats.

## Orchestration flowcharts

- [Four-chart overview](Documentation/Orchestration-Flowchart.md)
- [Chart 1 SVG](Documentation/images/Orchestration-Flowchart-1.svg)
- [Chart 2 SVG](Documentation/images/Orchestration-Flowchart-2.svg)
- [Chart 3 SVG](Documentation/images/Orchestration-Flowchart-3.svg)
- [Chart 4 SVG](Documentation/images/Orchestration-Flowchart-4.svg)
