# ATAP.Utilities.Plugin.Interfaces

## Purpose

Defines the core contracts (interfaces, enumerations, and event types) that govern the ATAP plugin system.
Any code that discovers, loads, or interacts with plugins depends only on this assembly — never on a
concrete plugin implementation.

Key contracts:

| Type                            | Description                                                                                                                             |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `IPluginMetadata`               | Name, version, and descriptive attributes of a plugin                                                                                   |
| `IPluginLifecycle`              | Load / unload / activate / deactivate hooks                                                                                             |
| `IPluginShim<TFamilyInterface>` | Generic shim contract — combines metadata and lifecycle with service access (`GetService()`) and DI registration (`RegisterServices()`) |
| `IPluginFamily<TInterface>`     | Represents a named family of interchangeable plugin implementations                                                                     |
| `IPluginData`                   | Runtime data payload exchanged between a plugin and the host                                                                            |
| `IPluginConfigStore`            | Per-plugin key/value configuration store                                                                                                |
| `PluginState`                   | Enumeration of plugin lifecycle states (Unloaded, Loaded, Active, …)                                                                    |
| `PluginDataChangeKind`          | Enumeration of data-change event categories                                                                                             |
| `PluginDataChangedEventArgs`    | Event arguments raised when plugin data changes                                                                                         |

## Architecture

The plugin interfaces follow the _shim pattern_ used throughout ATAP.Utilities:

```
Host / consumer code
   │
   ├─ IPluginFamily<T>      (discovers available plugins for family T)
   │     └─ IPluginShim<T>  (wraps one concrete implementation)
   │           ├─ IPluginMetadata    (who is this plugin?)
   │           ├─ IPluginLifecycle   (load / unload lifecycle)
   │           └─ T GetService()     (access the concrete service)
   │
   └─ IPluginConfigStore    (per-plugin configuration)
```

`TFamilyInterface` is the abstract service contract for a plugin family — for example
`ISecretsAbstract` for the secrets family, or `ISerializerAbstract` for the serializer family.
Consuming code works exclusively against these interfaces; concrete implementations live in
separate `*.Shim.*` assemblies.

## Prerequisites

- .NET 10.0 or later
- `Microsoft.Extensions.DependencyInjection.Abstractions` (for `IServiceCollection` used in `IPluginShim<T>.RegisterServices`)

## Setup

Reference the NuGet package `ATAP.Utilities.Plugin.Interfaces` in projects that need to discover or
interact with plugins without depending on any concrete implementation.

```xml
<PackageReference Include="ATAP.Utilities.Plugin.Interfaces" Version="*" />
```

Concrete shim assemblies (e.g. `ATAP.Utilities.Secrets.Shim.Plugin`) implement `IPluginShim<T>` and
are loaded at runtime by the host via `IPluginFamily<T>`.

## Known Issues

<!-- List any known issues -->

## Release Notes

<!-- Document release history and changes -->
