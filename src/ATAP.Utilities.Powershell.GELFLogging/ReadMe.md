# ATAP.Utilities.Powershell.GELFLogging

Explicit **enable / disable / query** control of PSFramework logging to a SEQ GELF (UDP)
ingestor.

Child module of `ATAP.Utilities.PowerShell`. Created by Sprint 0014 Task 14.62.

## Why this module exists

Two problems, both introduced by the sink living inside the parent umbrella module:

1. **No way to turn it off.** `Enable-SeqGelfLogging` shipped without a counterpart. The
   machine profile called it unconditionally for every non-SSH shell, and a session that
   should not ship telemetry — an offline host, a tight loop, a diagnostic run — had to
   reach into PSFramework internals or restart the shell.
2. **No way to ask.** Answering "is this shell shipping to SEQ, and where to?" required
   calling `Get-PSFLoggingProvider` / `Get-PSFLoggingProviderInstance` directly and already
   knowing the provider name and instance-naming convention.

Extracting the sink into its own child module also means a consumer that only needs GELF
control no longer imports the whole `ATAP.Utilities.PowerShell` umbrella — the smallest-
module principle Task 14.63 applies across the ecosystem.

## The underlying GELF provider

PSFramework ships a built-in `gelf` provider hard-coded to `PSGELF\Send-PSGelfTCP` — TCP
only. The organization's SEQ GELF input listens on **UDP** only, so the built-in provider
can never reach it, and the widely documented `PSFramework.logging.gelf.protocol`
configuration key does not exist (`Set-PSFConfig` creates it; nothing reads it).

This module registers its own Version2 provider named `gelfudp` with a real UDP send path
(Task 12.19 / SC-0230).

## Commands

| Command | Purpose |
| --- | --- |
| `Enable-SeqGelfLogging` | Register the provider if needed and enable a named instance. |
| `Disable-SeqGelfLogging` | Flush, then disable a named instance. Provider stays registered. |
| `Get-SeqGelfLoggingStatus` | Read-only. Reports registration, instance state, and endpoint. |

Instance naming follows the `SendTo<Sink>` convention from
`Rules Compendium.PowerShell`; the default instance is `SendToSEQ`.

## Usage

```powershell
# Turn the sink on against the local sqelf ingestor
Enable-SeqGelfLogging

# Point at a remote ingestor and prove a marker event actually landed in SEQ
Enable-SeqGelfLogging -GelfServer utat022 -Port 12201 -VerifyDelivery

# Ask before acting
if ((Get-SeqGelfLoggingStatus).Enabled) { Disable-SeqGelfLogging }

# Stop shipping immediately, discarding anything still queued
Disable-SeqGelfLogging -Flush:$false
```

## Dependencies

- **`PSFramework`** — required. Supplies the logging provider model.
- **`PSGELF`** — *not* a `RequiredModule`. It is the UDP transport, needed only by
  `Enable-SeqGelfLogging`, and is imported on demand. Requiring it would force a host that
  merely wants to **disable** or **query** the sink to install the transport first. It is
  declared in `PSData.ExternalModuleDependencies`.

## Secret handling

The SEQ API key is referenced **by SecretName only**, never as a literal. `-VerifyDelivery`
resolves it through `Get-SecretATAP` and sends it as the `X-Seq-ApiKey` header. If the
secret cannot be resolved, delivery is reported as *asserted, unverified* rather than
failing, and the key variable is cleared in a `finally` block.

## Behavioural notes worth knowing

- **Flush before disable.** PSFramework's logging runspace is asynchronous. Anything still
  queued when an instance stops is dropped without a diagnostic, so `Disable-SeqGelfLogging`
  drains first by default.
- **Disable is a safe no-op.** Disabling an instance that is not enabled, or a provider that
  was never registered, reports `WasEnabled = $false` instead of throwing — safe in profile
  teardown and in scripts that cannot know the current state.
- **Marker emission is doubled on purpose.** A logging instance starts asynchronously and
  messages logged before it finishes starting are *not* replayed. `Initialized` also lags
  actual readiness, so it cannot be polled. `-VerifyDelivery` therefore emits the marker
  across two flush cycles so at least one lands after start.

## Related

- `ATAP.Utilities.PowerShell` — parent umbrella module.
- `SolutionDocumentation/Rules Compendium.PowerShell.md` — GELF rule set.
