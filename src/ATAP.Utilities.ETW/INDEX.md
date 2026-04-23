# Index — ATAP.Utilities.ETW

## Source Files

| File                                     | Description                                                                                                                      |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| [ETWProvider.cs](ETWProvider.cs)         | `ATAPUtilitiesETWProvider` — singleton `EventSource` with Information, MethodBoundry, and MethodBoundryFromAspect event channels |
| [ETWLogAttribute.cs](ETWLogAttribute.cs) | `ETWLogAttribute` — Fody `OnMethodBoundaryAspect` that weaves ETW events on method entry, exit, and exception                    |
| [FodyWeavers.xml](FodyWeavers.xml)       | Fody weaver configuration enabling `MethodBoundaryAspect`                                                                        |

## Package

| Property         | Value                        |
| ---------------- | ---------------------------- |
| NuGet ID         | `ATAP.Utilities.ETW`         |
| Output type      | Library                      |
| Key dependency   | `MethodBoundaryAspect.Fody`  |
| EventSource name | `ATAP-Utilities-ETWProvider` |
