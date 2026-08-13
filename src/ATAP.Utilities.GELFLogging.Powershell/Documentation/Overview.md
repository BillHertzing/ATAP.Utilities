# ATAP.Utilities.GELFLogging.Powershell — Design Overview

## Scope

One job: control whether this PowerShell session ships PSFramework log messages to a SEQ
GELF (UDP) ingestor, and report whether it currently is.

## Why a separate module (Task 14.62)

The sink lived in the `ATAP.Utilities.PowerShell` umbrella. Three consequences:

1. The machine profile called `Enable-SeqGelfLogging` unconditionally on every non-SSH
   shell, and there was **no supported way to turn it back off**.
2. Asking "am I shipping telemetry, and where?" meant calling PSFramework's provider APIs
   directly and knowing the `gelfudp` provider name and the `SendTo<Sink>` instance
   convention.
3. A consumer that wanted only GELF control had to import the entire umbrella module.

## Why `gelfudp` exists rather than PSFramework's built-in `gelf`

PSFramework's built-in provider is hard-coded to `PSGELF\Send-PSGelfTCP` — TCP only. The
organization's SEQ GELF input listens on **UDP** only, so the built-in provider can never
reach it. The commonly cited `PSFramework.logging.gelf.protocol` configuration key does not
exist: `Set-PSFConfig` will happily create it and nothing ever reads it. (Task 12.19 / SC-0230.)

## Decisions

### Registration is separate from enabling

`Register-SeqGelfUdpProvider` is private and idempotent. Provider registration is
process-wide; enabling and disabling only toggle named *instances*. `Disable` therefore
leaves the provider registered — that costs nothing and makes a later `Enable` a cheap
toggle rather than a re-registration.

### Config is resolved per message, not cached in a StartEvent

A `StartEvent` cache races the first instance start: the configuration is not yet visible,
and every message is silently dropped until the instance is re-enabled. Reproduced
2026-07-04 — a fresh session's first enable never delivered, and a second
`Set-PSFLoggingProvider` call healed it. Resolving per message costs a config lookup and
removes the race.

### The marker is emitted twice

A logging instance starts asynchronously in the PSFramework logging runspace, and messages
logged before it finishes starting are **not** replayed. The instance's `Initialized`
property lags well behind actual readiness, so it cannot be polled as a readiness signal
(verified 2026-07-04). `-VerifyDelivery` emits the marker across two flush cycles so at
least one emission lands after the instance is live.

### Disable flushes first, by default

The logging runspace is asynchronous. Anything still queued for an instance is discarded
when that instance stops, with no diagnostic. `Disable-SeqGelfLogging` drains first;
`-Flush:$false` is available when you want the sink off immediately and accept the loss,
and it says so in `Notes`.

### Disable and query never require PSGELF

PSGELF is the UDP transport. Only `Enable` needs it, so the availability check lives in the
private `Assert-PSGelfAvailable` and PSGELF is declared as an *external* dependency rather
than a `RequiredModule`. Otherwise a host that merely wants to switch the sink **off** would
first have to install the transport it is trying to stop using.

### The SEQ API key is never a literal

`-VerifyDelivery` resolves the key by `SecretName` through `Get-SecretATAP`, sends it as the
`X-Seq-ApiKey` header, and clears the variable in a `finally`. An unresolvable secret
downgrades the result to *asserted, unverified* rather than failing the enable — losing
telemetry verification must not cost you telemetry.

## Output contracts

`Enable` returns `ProviderName`, `InstanceName`, `GelfServer`, `Port`, `Enabled`,
`ProviderInitialized`, `TestMarker`, `DeliveryVerified`, `Notes`.
`DeliveryVerified` is deliberately tri-state: `$true` found, `$false` queried but absent,
`$null` could not query.

`Disable` returns `ProviderName`, `InstanceName`, `WasEnabled`, `Enabled`, `Flushed`, `Notes`.

`Get-SeqGelfLoggingStatus` returns `ProviderName`, `Registered`, `InstanceName`,
`InstanceExists`, `Enabled`, `GelfServer`, `Port`, `Endpoint`.
