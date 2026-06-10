# TRACE / ETW Configuration

**Source:** Migrated from `_Planning/Explainers/0107-build-artifacts-trace-etw.md` §2
(rows `0107-etw`) during Sprint 0007 Explainer Elimination (Stream S7).

This document describes the Trace build configuration used by ATAP libraries to
emit structured ETW (Event Tracing for Windows) diagnostic events, the per-library
provider naming convention, how Trace packages are consumed by Testers and Debug
Engineers, and the `.Trace` package-ID suffix convention that distinguishes a Trace
package from its standard counterpart.

---

## What Is a Trace Build?

A Trace build is a Release-optimized compilation that additionally includes **ETW
Event Sources** -- structured event providers that emit diagnostic data to the
Windows ETW subsystem. The Trace configuration is defined by two compiler
constants:

```xml
<DefineConstants>TRACE;ETW_ENABLED</DefineConstants>
```

Code guarded by `#if TRACE` or `#if ETW_ENABLED` is compiled in:

```csharp
#if ETW_ENABLED
[EventSource(Name = "ATAP-Utilities-Serialization")]
public sealed class SerializationEventSource : EventSource
{
    public static readonly SerializationEventSource Log = new();

    [Event(1, Message = "Serialize start: {0}", Level = EventLevel.Informational)]
    public void SerializeStart(string typeName) => WriteEvent(1, typeName);

    [Event(2, Message = "Serialize complete: {0} ({1} ms)", Level = EventLevel.Informational)]
    public void SerializeComplete(string typeName, long elapsedMs) => WriteEvent(2, typeName, elapsedMs);
}
#endif
```

In Release and Debug builds, these event sources are not compiled, so there is
zero overhead.

---

## ETW Provider Architecture

Each ATAP library that participates in tracing defines its own ETW Event Source
with a unique provider name:

| Library                      | ETW Provider Name              | Provider GUID            |
| ---------------------------- | ------------------------------ | ------------------------ |
| ATAP.Utilities.Serialization | `ATAP-Utilities-Serialization` | Auto-generated from name |
| ATAP.Utilities.Persistence   | `ATAP-Utilities-Persistence`   | Auto-generated from name |
| ATAP.Utilities.Http          | `ATAP-Utilities-Http`          | Auto-generated from name |
| AceCommander.Server          | `AceCommander-Server`          | Auto-generated from name |

The Trace package includes an **ETW manifest file** (`etw-manifest.xml`) that
lists all providers, their events, and their schemas. This allows ETW consumers
(Windows Performance Analyzer, PerfView, dotnet-trace) to decode the events.

---

## How Trace Packages Are Used

### Performance Testing

The **Tester** role uses Trace packages during the Testing tier:

1. Install the Trace package variant from `nuget-testing`
2. Start an ETW tracing session targeting the library's providers:

   ```powershell
   # Using dotnet-trace
   dotnet-trace collect --providers "ATAP-Utilities-Serialization:Informational" `
       --process-id $pid --output trace.nettrace

   # Or using logman
   logman create trace ATAPPerf -p "ATAP-Utilities-Serialization" -o perf.etl -ets
   ```

3. Run the performance test suite against the `Testing-Perf` database instance
4. Stop tracing and analyze:

   ```powershell
   dotnet-trace convert trace.nettrace --format speedscope
   # Open in https://www.speedscope.app/ or Windows Performance Analyzer
   ```

5. Compare results against `baseline-measurements.json` from the previous version

### Diagnosing Recalcitrant User Problems

The **Debug Engineer** role uses Trace packages to investigate issues that
cannot be reproduced with standard logging:

1. Deploy the Trace version of the affected library to the user's environment
2. Enable ETW tracing for the relevant providers
3. Reproduce the problem (the Trace build emits structured events at each
   operation boundary)
4. Collect the .etl trace file
5. Analyze the trace to identify the root cause
6. Replace the Trace package with the standard Release package after diagnosis

### Why This Is Less Invasive Than a Debug Build

Deploying a Trace package to a user's environment is significantly less
invasive than deploying a Debug build because:

- Trace builds are Release-optimized (same performance characteristics)
- ETW providers have near-zero overhead when no consumer is listening
- Structured events provide richer context than debug logging

---

## Trace Package Identity and Contents

The Trace package is a **separate package** with a `.Trace` suffix on the
package ID. For example, `ATAP.Utilities.Serialization` has a companion
`ATAP.Utilities.Serialization.Trace`. Both share the same version number and
source commit. The `.Trace` suffix is a **package ID convention, not a version
suffix**.

```path
{PackageId}.Trace.{Version}.nupkg
  ├── lib/
  │   ├── net8.0/{Assembly}.dll          # Trace-compiled
  │   ├── net9.0/{Assembly}.dll
  │   └── net10.0/{Assembly}.dll
  ├── contentFiles/
  │   ├── etw-manifest.xml               # Provider definitions
  │   ├── perf/
  │   │   ├── baseline-measurements.json # Previous version's metrics
  │   │   └── test-harness.dll           # Performance test runner
  │   └── symbols/
  │       ├── {Assembly}.pdb             # Full symbols for profiling
  │       └── source-link.json           # Source link for decompilation
  └── build/
      └── {PackageId}.Trace.targets      # MSBuild integration
```

**Trace package publication and retention:**

- Trace packages are built and published by BuildMaster CI only at the Testing
  tier
- They are published to `nuget-testing` alongside the standard QA package
- Trace packages are retained per the ProGet retention policy for the testing
  feed
- Consumers must explicitly reference the `.Trace` package ID; standard
  package consumers are never affected
