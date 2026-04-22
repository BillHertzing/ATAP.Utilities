# Index — ATAP.Utilities.Plugin.Interfaces

## Contents

| File                                                           | Description                                                                              |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [ReadMe.md](ReadMe.md)                                         | Project documentation                                                                    |
| [IPluginConfigStore.cs](IPluginConfigStore.cs)                 | Per-plugin key/value configuration store contract                                        |
| [IPluginData.cs](IPluginData.cs)                               | Runtime data payload contract exchanged between plugin and host                          |
| [IPluginFamily.cs](IPluginFamily.cs)                           | Contract for a named family of interchangeable plugin implementations                    |
| [IPluginLifecycle.cs](IPluginLifecycle.cs)                     | Load / unload / activate / deactivate lifecycle hooks                                    |
| [IPluginMetadata.cs](IPluginMetadata.cs)                       | Name, version, and descriptive attributes of a plugin                                    |
| [IPluginShim.cs](IPluginShim.cs)                               | Generic shim contract combining metadata, lifecycle, service access, and DI registration |
| [PluginDataChangedEventArgs.cs](PluginDataChangedEventArgs.cs) | Event arguments raised when plugin data changes                                          |
| [PluginDataChangeKind.cs](PluginDataChangeKind.cs)             | Enumeration of data-change event categories                                              |
| [PluginState.cs](PluginState.cs)                               | Enumeration of plugin lifecycle states                                                   |
