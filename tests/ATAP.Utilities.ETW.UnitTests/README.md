# Utilities ETW proof toolkit

This directory contains the reusable Utilities EventSource proof toolkit created by
Task 15.181.n.U00. Keep build output outside the repository and Dropbox by supplying
the canonical external artifact properties shown in the durable usage guide.

## Reusable assets

| Asset | Purpose |
| :--- | :--- |
| `HarnessSyntheticProbeTests.cs` | In-process `EventListener` lifecycle fixture covering disabled-provider silence, success, fault, and cancellation. |
| `SyntheticRunner/Program.cs` | Deterministic six-event child process used to prove `dotnet-trace` collection and decoder wiring without invoking a production operation. |
| `UtilitiesEtwTraceDecoder.cs` | TraceEvent-based `.nettrace` decoder plus an environment-variable-driven xUnit entry point that emits JSON rows. |
| `BoundedOperationRunner.cs.template` | Harness-generated reflection runner for one validated static synchronous operation. It is not a general command runner. |
| `Invoke-UtilitiesEtwProofHarness.ps1` | Six-parameter orchestration entry point for locked restore/build, IL inspection, EventListener proof, EventPipe capture, decode, and redaction checks. |
| `UtilitiesEtwProofHarness.Tests.ps1` | Fail-closed contract and portability tests for the PowerShell harness. |

## Durable usage guide

The cross-sprint guide, known-good commands, provider identity, safety boundary, and
asset SHA-256 manifest are preserved in the Planning repository at:

`InformationForTheFuture/Sprint0015/StreamR/Task-15.181.n-ETW-Proof-Toolkit.md`

The guide is authoritative for future reuse. Task evidence under `_generated/` proves
past runs but is not a durable source of instructions.
