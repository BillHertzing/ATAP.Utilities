# ATAP.Utilities.ETW

## Purpose

Provides ETW (Event Tracing for Windows) infrastructure for the ATAP.Utilities ecosystem. Exposes a singleton `ATAPUtilitiesETWProvider` EventSource and an `ETWLogAttribute` Fody aspect that automatically instruments method entry, exit, and exception events at compile time — with zero boilerplate in consumer code.

## Architecture

The library has two cooperating components:

- **`ATAPUtilitiesETWProvider`** — A sealed `EventSource` named `ATAP-Utilities-ETWProvider`. Defines three typed event channels:
  - `Information` (EventId 1) — general informational messages.
  - `MethodBoundry` (EventId 2) — manual method-boundary messages.
  - `MethodBoundryFromAspect` (EventId 3) — automatic method-boundary messages emitted by the Fody aspect.

- **`ETWLogAttribute`** — A `OnMethodBoundaryAspect` (Fody / MethodBoundaryAspect.Fody). Decorate any method or class with `[ETWLog]` and Fody weaves `OnEntry`, `OnExit`, and `OnException` calls into the IL at build time, emitting events to `ATAPUtilitiesETWProvider.Log` without modifying source code.

Fody weaving is configured via `FodyWeavers.xml` (`<MethodBoundaryAspect />`).

## Prerequisites

- .NET (see `global.json` at solution root for the required SDK version)
- The `MethodBoundaryAspect.Fody` NuGet package (declared in the project file; Fody runs during the build)
- An ETW consumer tool to collect events, such as PerfView, dotnet-trace, or Windows Performance Recorder

## Setup

1. Add a package reference to `ATAP.Utilities.ETW`.
2. To emit a general message manually:
   ```csharp
   ATAPUtilitiesETWProvider.Log.Information("my message");
   ```
3. To automatically trace all methods in a class at the ETW level, annotate with the attribute:
   ```csharp
   [ETWLog]
   public class MyService { ... }
   ```
   Fody weaves the entry/exit/exception events at build time.
4. Collect events with PerfView or `dotnet-trace`:
   ```
   dotnet-trace collect --providers ATAP-Utilities-ETWProvider -- <yourapp>
   ```

## Known Issues

- The `MethodBoundry` event name is intentionally spelled without the trailing 'a' (matches the existing EventSource manifest; changing it would be a breaking schema change).
- Parameter values are not currently logged on method entry (the relevant code is commented out in `ETWLogAttribute.cs`).

## Release Notes

<!-- Document release history and changes -->
