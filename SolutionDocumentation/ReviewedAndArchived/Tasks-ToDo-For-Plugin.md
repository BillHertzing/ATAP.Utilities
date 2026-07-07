# Tasks ToDo For Plugin Architecture

> **Archived 2026-07-06** (Sprint 0012 Task 12.45.e, documentation reorganization per
> `PlanDocumentationReorganization.md`). Superseded by `GenericPluginArchitecture.md`.
> Retained as decision/analysis history; do not update.

> **Created:** 2026-04-05
> **Status:** Planning
> **Context documents:**
> - [GenericPluginArchitecture.md](GenericPluginArchitecture.md) -- full architecture spec
> - [SecretsPluginArchitecture.md](SecretsPluginArchitecture.md) -- Secrets family spec
> - [PLugin Creation Prompt.md](PLugin%20Creation%20Prompt.md) -- original requirements
> **Branch:** `94-sprint-0004-work-items`

---

## Recovery Context (for restarts)

This document was created from a gap analysis performed on the plugin architecture work.
Here is what already exists as of 2026-04-05:

**Completed code:**
- `ATAP.Utilities.Plugin.Interfaces` -- all 9 files, compiles, NuGet packaged
- `ATAP.Utilities.Plugin.Model` -- `PluginShimBase<T>`, `PluginDataBase`, `InMemoryPluginConfigStore`; compiles
- `ATAP.Utilities.Plugin.StringConstants` -- compiles
- `ATAP.Utilities.Plugin` facade .csproj -- compiles
- `ATAP.Utilities.Loader.Interfaces/ILoader.cs` -- updated with `ILoadedAssemblyContext`, `IAssemblyLoader`
- `ATAP.Utilities.Loader/CollectibleAssemblyLoadContext.cs` -- new, native ALC
- `ATAP.Utilities.Loader/LoadedAssemblyContext.cs` -- new, wrapper
- `ATAP.Utilities.Loader/NativeAssemblyLoader.cs` -- new, `IAssemblyLoader` impl

**Not yet started:**
- `PluginFamilyBase<T>` (the orchestrator class)
- Entire `ATAP.Utilities.Secrets` family (zero files)
- `ATAP.Console.PluginDemo`
- All unit tests for new Plugin/Loader code
- Loader.cs migration off McMaster
- PowerShell module

**Key reference:** The Serializer family (`src/ATAP.Utilities.Serializer/`) is the most
mature plugin family. It has Interfaces, Model, StringConstants, Shim facade, and
Shim/{Newtonsoft,ServiceStack,SystemTextJson,Plugin} subprojects. Use it as the
structural template for the Secrets family.

**Key reference:** The old secrets implementations live at:
- `src/ATAP.Utilities.Configuration.Secrets/` (Implementation A -- rich options, SecretMapping)
- `src/ATAP.Utilities.Configuration/Secrets/Shims/` (Implementation B -- shim pattern, router)

---

## Agent Assignments

| Agent | Focus Area | Skills Needed |
|-------|-----------|---------------|
| **Agent 1** | Loader refactoring + Plugin framework completion | AssemblyLoadContext, generics, reflection |
| **Agent 2** | Secrets family -- Interfaces, Model, StringConstants, Enumerations | Interface design, Options pattern |
| **Agent 3** | Secrets family -- Shim/Bitwarden implementation | Process management, IConfiguration, DI |
| **Agent 4** | Secrets family -- Shim/Plugin + Demo console app | Dynamic loading, DI, integration |
| **Agent 5** | Unit tests (all packages) | xUnit, FluentAssertions, Moq |

---

## Dependency Graph (read: "X blocks Y")

```
Phase 0 (no dependencies -- can start immediately):
  Tasks 1-5   (Agent 1: Loader cleanup)
  Tasks 6-13  (Agent 2: Secrets Interfaces + Model + StringConstants + Enumerations)
  Tasks 14-15 (Agent 5: Plugin.Interfaces + Plugin.Model tests)

Phase 1 (depends on Phase 0 Loader tasks 1-5):
  Tasks 16-19 (Agent 1: PluginFamilyBase + Loader method migration)

Phase 2 (depends on Phase 0 Secrets interfaces tasks 6-9):
  Tasks 20-27 (Agent 3: Bitwarden shim implementation)
  Task 28     (Agent 4: Secrets.Shim facade .csproj)

Phase 3 (depends on Phase 1 tasks 16-19 AND Phase 2 tasks 20-27):
  Tasks 29-32 (Agent 4: Secrets.Shim.Plugin + Secrets facade)
  Tasks 33-37 (Agent 5: Loader + Secrets tests)

Phase 4 (depends on Phase 3):
  Tasks 38-42 (Agent 4: PluginDemo console app)
  Tasks 43-46 (Agent 5: Integration tests)

Phase 5 (depends on Phase 4):
  Tasks 47-50 (Agents 1+3: Cleanup, deprecation, PowerShell)
```

---

## Task List

### Phase 0 -- No Dependencies (Start Immediately)

---

#### Agent 1: Loader Cleanup

**Task 1: Remove McMaster PackageReference from Loader .csproj**
- [ ] File: `src/ATAP.Utilities.Loader/ATAP.Utilities.Loader.csproj`
- Remove the `<PackageReference Include="McMaster.NETCore.Plugins" />` (line 44)
- This will cause Loader.cs to stop compiling, which is expected -- tasks 2-4 fix it
- **Blocked by:** nothing
- **Blocks:** Tasks 2, 3, 4

**Task 2: Add IAssemblyLoader as a constructor dependency to Loader\<T\>**
- [ ] File: `src/ATAP.Utilities.Loader/Loader.cs`
- Change `LoaderAbstract<IType>` to accept `IAssemblyLoader` as constructor param
- Change `Loader<IType>` to accept `IAssemblyLoader` in its constructor, store as `_assemblyLoader`
- Default to `new NativeAssemblyLoader()` if none provided (parameterless ctor overload)
- **Blocked by:** Task 1
- **Blocks:** Tasks 3, 4, 5

**Task 3: Rewrite LoadExactlyOneInstanceOfITypeFromAssemblyGlob to use IAssemblyLoader**
- [ ] File: `src/ATAP.Utilities.Loader/Loader.cs`
- Replace all `PluginLoader.CreateFromAssemblyFile()` calls with `_assemblyLoader.LoadAssembly()`
- Replace `loader.LoadDefaultAssembly()` with `loadedContext.LoadedAssembly`
- Preserve existing glob expansion via `dynamicGlobAndPredicate.Glob.ExpandNames()`
- Preserve `ILoadDynamicSubModules` detection and sub-module loading logic
- Track `ILoadedAssemblyContext` references for later unload
- **Blocked by:** Task 2
- **Blocks:** Task 5, 16

**Task 4: Rewrite LoadAndProcessZeroOrMoreInstanceOfITypeFromAssemblyGlob to use IAssemblyLoader**
- [ ] File: `src/ATAP.Utilities.Loader/Loader.cs`
- Same pattern as Task 3 but for the zero-or-more method
- Replace McMaster `PluginLoader` with `_assemblyLoader.LoadAssembly()`
- **Blocked by:** Task 2
- **Blocks:** Task 5, 16

**Task 5: Delete commented-out dead code from Loader.cs**
- [ ] File: `src/ATAP.Utilities.Loader/Loader.cs`
- Remove all commented-out code blocks (lines ~170-441)
- Remove the empty `LoaderFactory` class (or implement if needed by PluginFamilyBase)
- Remove commented-out `LoaderStatic<IType>` class
- Clean up unused `using` statements
- **Blocked by:** Tasks 3, 4
- **Blocks:** nothing (cleanup only)

---

#### Agent 2: Secrets Family -- Interfaces, Model, StringConstants, Enumerations

> **Reference:** SecretsPluginArchitecture.md Sections 3-7 for specs.
> **Structural template:** `src/ATAP.Utilities.Serializer/` for folder layout and .csproj patterns.
> **Existing code to consolidate:** `src/ATAP.Utilities.Configuration.Secrets/ISecretProvider.cs`
>   and `src/ATAP.Utilities.Configuration/Secrets/Shims/Interfaces/`.

**Task 6: Create Secrets/Interfaces .csproj and ISecretsAbstract.cs**
- [ ] Create folder: `src/ATAP.Utilities.Secrets/Interfaces/`
- [ ] Create: `ATAP.Utilities.Secrets.Interfaces.csproj` (copy pattern from Plugin.Interfaces.csproj)
  - PackageReferences: `Microsoft.Extensions.Configuration.Abstractions`
  - ProjectReference to `ATAP.Utilities.Plugin.Interfaces` (for `IPluginShim<T>`)
- [ ] Create: `ISecretsAbstract.cs` per SecretsPluginArchitecture.md Section 4.1
  - Namespace: `ATAP.Utilities.Secrets`
  - Members: `Options`, `ProviderName`, `IsAvailable()`, `GetSecretAsync()`, `SecretExistsAsync()`
- [ ] Create: `Properties/AssemblyInfo.cs`
- **Blocked by:** nothing
- **Blocks:** Tasks 8, 9, 10, 11, 12, 13, 20

**Task 7: Create ISecretsOptionsAbstract.cs and ISecretsConfigurableAbstract.cs**
- [ ] File: `src/ATAP.Utilities.Secrets/Interfaces/ISecretsOptionsAbstract.cs`
  - Per SecretsPluginArchitecture.md Section 4.3: `ShimSpecificOptions` property
- [ ] File: `src/ATAP.Utilities.Secrets/Interfaces/ISecretsConfigurableAbstract.cs`
  - Per Section 4.2: extends `ISecretsAbstract`, adds `IConfigurationRoot?`
- **Blocked by:** Task 6
- **Blocks:** Tasks 10, 11, 20

**Task 8: Create ISecretsPluginShim.cs**
- [ ] File: `src/ATAP.Utilities.Secrets/Interfaces/ISecretsPluginShim.cs`
  - Per Section 4.4: extends `IPluginShim<ISecretsAbstract>`, adds `CreateConfigurationSource()`
  - Requires `SecretMapping` type from Task 10 -- use forward reference or put in same task
- **Blocked by:** Task 6
- **Blocks:** Task 29

**Task 9: Create Secrets/Enumerations .csproj and SecretsProviderKind.cs**
- [ ] Create folder: `src/ATAP.Utilities.Secrets/Enumerations/`
- [ ] Create: `ATAP.Utilities.Secrets.Enumerations.csproj` (minimal, no project references needed)
- [ ] Create: `SecretsProviderKind.cs` per Section 7 of Secrets spec
  - Values: `BitwardenPasswordManager`, `BitwardenSecretsManager`, `AzureKeyVault`, etc.
- [ ] Create: `Properties/AssemblyInfo.cs`
- **Blocked by:** nothing (no dependencies on other Secrets projects)
- **Blocks:** Task 13 (facade)

**Task 10: Create Secrets/Model .csproj and abstract base classes**
- [ ] Create folder: `src/ATAP.Utilities.Secrets/Model/`
- [ ] Create: `ATAP.Utilities.Secrets.Model.csproj`
  - ProjectReference to `Secrets.Interfaces`, `Plugin.Model` (for `PluginShimBase<T>`)
- [ ] Create: `SecretsAbstract.cs` -- abstract class implementing `ISecretsAbstract`
- [ ] Create: `SecretsConfigurableAbstract.cs` -- extends `SecretsAbstract`, implements `ISecretsConfigurableAbstract`
- [ ] Create: `SecretsOptionsAbstract.cs` -- implements `ISecretsOptionsAbstract`
- [ ] Create: `Properties/AssemblyInfo.cs`
- **Blocked by:** Tasks 6, 7
- **Blocks:** Tasks 11, 20

**Task 11: Create SecretMapping.cs and SecretsRouter.cs in Model**
- [ ] File: `src/ATAP.Utilities.Secrets/Model/SecretMapping.cs`
  - Per Section 5.1: `record SecretMapping(string SecretName, string? FieldName, string ConfigurationKey)`
  - Consolidates `SecretMapping` from Implementation A and `BitwardenSecretMapping` from Implementation B
- [ ] File: `src/ATAP.Utilities.Secrets/Model/SecretsRouter.cs`
  - Per Section 5.2: extends `SecretsAbstract`, iterates providers, returns first non-null
- **Blocked by:** Task 10
- **Blocks:** Tasks 20, 29

**Task 12: Create Secrets/StringConstants .csproj and StringConstants.cs**
- [ ] Create folder: `src/ATAP.Utilities.Secrets/StringConstants/`
- [ ] Create: `ATAP.Utilities.Secrets.StringConstants.csproj` (minimal, no project references)
- [ ] Create: `StringConstants.cs` per Section 6 of Secrets spec
  - Config root keys, default values, Bitwarden-specific constants, exception messages
- [ ] Create: `Properties/AssemblyInfo.cs`
- **Blocked by:** nothing
- **Blocks:** Task 13 (facade), Task 20

**Task 13: Create Secrets facade .csproj**
- [ ] Create: `src/ATAP.Utilities.Secrets/ATAP.Utilities.Secrets.csproj`
  - `EnableDefaultItems=false` (facade pattern)
  - ProjectReferences to: Interfaces, Model, StringConstants, Enumerations
  - Copy pattern from `ATAP.Utilities.Plugin.csproj` or `ATAP.Utilities.Serializer.csproj`
  - Include Fody/ETW references per convention
- [ ] Create: `src/ATAP.Utilities.Secrets/Properties/AssemblyInfo.cs`
- [ ] Create: `src/ATAP.Utilities.Secrets/FodyWeavers.xml` (copy from Plugin)
- **Blocked by:** Tasks 6, 9, 10, 12
- **Blocks:** Task 32 (facade builds)

---

#### Agent 5: Early Tests (Plugin packages)

**Task 14: Create unit tests for ATAP.Utilities.Plugin.Interfaces enums and event args**
- [ ] Create folder: `tests/ATAP.Utilities.Plugin.Interfaces.UnitTests/`
- [ ] Create .csproj referencing Plugin.Interfaces, xUnit, FluentAssertions
- [ ] Test `PluginState` enum has all expected values (Discovered through Unloaded)
- [ ] Test `PluginDataChangeKind` enum values
- [ ] Test `PluginDataChangedEventArgs` property setters/getters
- **Blocked by:** nothing
- **Blocks:** nothing

**Task 15: Create unit tests for Plugin.Model classes**
- [ ] Create folder: `tests/ATAP.Utilities.Plugin.Model.UnitTests/`
- [ ] Create .csproj referencing Plugin.Model, Plugin.Interfaces, xUnit, FluentAssertions, Moq
- [ ] Tests for `PluginDataBase`:
  - `Set()` adds entry, `DataStore` returns deep copy, `DataChanged` fires, `Remove()` works
  - Verify deep-copy semantics (mutating returned object doesn't affect store)
  - Verify `IObservable<T>` subscribe/unsubscribe
- [ ] Tests for `InMemoryPluginConfigStore`:
  - `GetAsync`/`SetAsync` round-trip
  - `GetKeysAsync` prefix filtering
  - `RemoveAsync` removes key
  - JSON file persistence on dispose (create temp file, verify contents)
- [ ] Tests for `PluginShimBase<T>`:
  - Valid state transitions (Discovered -> Loaded -> Configured -> Active -> Deactivating -> Unloaded)
  - Invalid state transition throws `InvalidOperationException`
  - Create a test subclass (`TestPluginShim : PluginShimBase<IDisposable>`) to test abstract base
- **Blocked by:** nothing
- **Blocks:** nothing

---

### Phase 1 -- Depends on Phase 0 Loader Tasks (1-5)

---

#### Agent 1: Plugin Framework Completion

**Task 16: Implement PluginFamilyBase\<T\>**
- [ ] File: `src/ATAP.Utilities.Plugin/Model/PluginFamilyBase.cs`
- Implements `IPluginFamily<T>` (from Plugin.Interfaces)
- Constructor takes `IAssemblyLoader`, `IPluginConfigStore` (optional), probing path (string)
- `DiscoverAsync()`: glob probing directory for matching DLLs, populate `DiscoveredPlugins` list
- `LoadAsync(pluginId)`: use `_assemblyLoader.LoadAssembly()`, find `IPluginShim<T>` type via reflection, instantiate, call `MarkLoaded()`, return shim
- `UnloadAsync(pluginId)`: call `DeactivateAsync()` + `UnloadAsync()` on shim, dispose `ILoadedAssemblyContext`
- `ActivePlugin` property for current active plugin
- **Reference:** GenericPluginArchitecture.md Sections 3.2, 4.1, 4.2
- **Blocked by:** Tasks 3, 4 (Loader must use IAssemblyLoader)
- **Blocks:** Tasks 29, 38

**Task 17: Add PluginFamilyBase\<T\> to Plugin.Model .csproj references**
- [ ] File: `src/ATAP.Utilities.Plugin/Model/ATAP.Utilities.Plugin.Model.csproj`
- Add ProjectReference to `ATAP.Utilities.Loader.Interfaces` (for `IAssemblyLoader`)
- Add ProjectReference to `ATAP.Utilities.Loader` (for `NativeAssemblyLoader` default)
- **Blocked by:** Task 16
- **Blocks:** nothing (enables compilation of Task 16)

**Task 18: Flesh out LoaderOptions with real properties**
- [ ] File: `src/ATAP.Utilities.Loader/LoaderOptions.cs`
- [ ] File: `src/ATAP.Utilities.Loader.Interfaces/ILoaderOptions.cs`
- Replace stub `bool Additional` with meaningful properties:
  - `string ProbingPath` (default: "Plugins")
  - `int MaxProbingDepth` (default: 1)
  - `bool UseCollectibleContexts` (default: true)
  - `Type[] SharedTypes` (default: empty)
- **Blocked by:** Tasks 1-4
- **Blocks:** nothing

**Task 19: Add new LoadAndRegister\<TInterface\> method to Loader\<T\>**
- [ ] File: `src/ATAP.Utilities.Loader/Loader.cs`
- Per GenericPluginArchitecture.md Section 5.4 new method table:
  `LoadAndRegister<TInterface>(glob, services, lifetime)` -- discover, load, register in DI
- This is a convenience method combining `LoadExactlyOne` + `services.Add{Lifetime}`
- **Blocked by:** Tasks 3, 4
- **Blocks:** nothing (nice-to-have convenience)

---

### Phase 2 -- Depends on Secrets Interfaces (Tasks 6-9)

---

#### Agent 3: Bitwarden Shim Implementation

> **Key sources to consolidate:**
> - `src/ATAP.Utilities.Configuration.Secrets/Providers/BitwardenPasswordManagerProvider.cs` (rich options, process mgmt)
> - `src/ATAP.Utilities.Configuration/Secrets/Shims/Bitwarden/ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden.cs` (cleaner RunBwAsync)
> Read both files before starting. The consolidation strategy is in SecretsPluginArchitecture.md Section 2.3.

**Task 20: Create Shim/Bitwarden .csproj**
- [ ] Create folder: `src/ATAP.Utilities.Secrets/Shim/Bitwarden/`
- [ ] Create: `ATAP.Utilities.Secrets.Shim.Bitwarden.csproj`
  - ProjectReferences: `Secrets.Interfaces`, `Secrets.Model`, `Secrets.StringConstants`
  - PackageReferences: `Microsoft.Extensions.Configuration.Abstractions`, `Microsoft.Extensions.DependencyInjection.Abstractions`, `Microsoft.Extensions.Options`
  - Include Fody/ETW references per convention
- [ ] Create: `Properties/AssemblyInfo.cs`
- [ ] Create: `FodyWeavers.xml` (copy from Plugin)
- **Blocked by:** Tasks 6, 7, 10, 12
- **Blocks:** Tasks 21-27

**Task 21: Implement BitwardenSecretsOptions.cs**
- [ ] File: `src/ATAP.Utilities.Secrets/Shim/Bitwarden/BitwardenSecretsOptions.cs`
- Per SecretsPluginArchitecture.md Section 8.1
- Properties: `SessionEnvVarName`, `BwCliPath`, `Timeout`, `DefaultFieldName`
- All defaults from `StringConstants`
- **Blocked by:** Task 20
- **Blocks:** Tasks 22, 24, 25, 26

**Task 22: Implement BitwardenSecretsShim.cs**
- [ ] File: `src/ATAP.Utilities.Secrets/Shim/Bitwarden/BitwardenSecretsShim.cs`
- Per SecretsPluginArchitecture.md Section 8.2
- Extends `SecretsConfigurableAbstract` (from Task 10)
- `IsAvailable()`: check env var for session key
- `GetSecretAsync()`: `bw get password` for password field, `bw get item` + JSON parse for custom fields
- `SecretExistsAsync()`: `bw get item` exit code check
- Private `RunBwAsync()` method: `Process.Start` with `_options.BwCliPath`, `_options.Timeout`, pass `BW_SESSION` env var
- Private `ExtractCustomField()`: parse `bw get item` JSON output, find field by name
- **Consolidation note:** Use RunBwAsync pattern from Implementation B, enrich with BwCliPath/Timeout from Implementation A
- **Blocked by:** Tasks 10, 21
- **Blocks:** Tasks 24, 25, 26, 27

**Task 23: Implement SecretsOptions.cs (wrapper)**
- [ ] File: `src/ATAP.Utilities.Secrets/Shim/Bitwarden/SecretsOptions.cs`
  - Or place in `Secrets/Model/` if it's the generic wrapper
- Implements `ISecretsOptionsAbstract` with `ShimSpecificOptions` returning the `BitwardenSecretsOptions`
- This is the bridge between the abstract options interface and the Bitwarden-specific options
- **Blocked by:** Tasks 7, 21
- **Blocks:** Task 22

**Task 24: Implement BitwardenConfigurationSource.cs**
- [ ] File: `src/ATAP.Utilities.Secrets/Shim/Bitwarden/BitwardenConfigurationSource.cs`
- Implements `IConfigurationSource`
- Constructor takes `BitwardenSecretsOptions` + `IEnumerable<SecretMapping>`
- `Build()` returns a `BitwardenConfigurationProvider`
- **Blocked by:** Tasks 21, 22
- **Blocks:** Task 25

**Task 25: Implement BitwardenConfigurationProvider.cs**
- [ ] File: `src/ATAP.Utilities.Secrets/Shim/Bitwarden/BitwardenConfigurationProvider.cs`
- Per SecretsPluginArchitecture.md Section 10.2
- Extends `ConfigurationProvider`
- `Load()`: if `IsAvailable()`, iterate `SecretMapping`s, call `GetSecretAsync().GetAwaiter().GetResult()`, populate `Data` dictionary
- Silently skip if not available (missing secrets caught by `ValidateOnStart`)
- **Blocked by:** Tasks 22, 24
- **Blocks:** Task 27

**Task 26: Implement ServiceCollectionExtensions.cs for Bitwarden**
- [ ] File: `src/ATAP.Utilities.Secrets/Shim/Bitwarden/ServiceCollectionExtensions.cs`
- Per SecretsPluginArchitecture.md Section 8.3
- `AddBitwardenSecrets(this IServiceCollection, Action<BitwardenSecretsOptions>?)` -- registers `ISecretsAbstract` singleton
- **Blocked by:** Task 22
- **Blocks:** Task 38

**Task 27: Implement ConfigurationBuilderExtensions.cs for Bitwarden**
- [ ] File: `src/ATAP.Utilities.Secrets/Shim/Bitwarden/ConfigurationBuilderExtensions.cs`
- Per SecretsPluginArchitecture.md Section 8.3
- `AddBitwardenSecrets(this IConfigurationBuilder, IEnumerable<SecretMapping>, Action<BitwardenSecretsOptions>?)`
- Creates `BitwardenConfigurationSource` and adds it to builder
- **Blocked by:** Tasks 24, 25
- **Blocks:** Task 38

---

#### Agent 4: Secrets Shim Facade

**Task 28: Create Secrets/Shim facade .csproj**
- [ ] Create: `src/ATAP.Utilities.Secrets/Shim/ATAP.Utilities.Secrets.Shim.csproj`
  - `EnableDefaultItems=false` (facade pattern)
  - ProjectReference to `Shim/Bitwarden/ATAP.Utilities.Secrets.Shim.Bitwarden.csproj`
  - (Future: will also reference AzureKeyVault, KeePass, etc.)
  - Include Fody/ETW per convention
- [ ] Create: `Properties/AssemblyInfo.cs`
- **Blocked by:** Tasks 6-12 (Secrets interfaces must exist)
- **Blocks:** Task 32

---

### Phase 3 -- Depends on Phase 1 (PluginFamilyBase) AND Phase 2 (Bitwarden Shim)

---

#### Agent 4: Secrets Plugin Shim + Secrets Facade

**Task 29: Create Secrets/Shim/Plugin .csproj**
- [ ] Create folder: `src/ATAP.Utilities.Secrets/Shim/Plugin/`
- [ ] Create: `ATAP.Utilities.Secrets.Shim.Plugin.csproj`
  - ProjectReferences: `Secrets.Interfaces`, `Secrets.StringConstants`, `Loader.Interfaces`, `Plugin.Interfaces`, `Plugin.Model`
  - Include Fody/ETW per convention
- [ ] Create: `Properties/AssemblyInfo.cs`
- [ ] Create: `FodyWeavers.xml`
- **Blocked by:** Tasks 6, 8, 16
- **Blocks:** Task 30

**Task 30: Implement SecretsPluginShim.cs**
- [ ] File: `src/ATAP.Utilities.Secrets/Shim/Plugin/SecretsPluginShim.cs`
- Per SecretsPluginArchitecture.md Section 9.1
- Extends `PluginShimBase<ISecretsAbstract>`, implements `ILoadDynamicSubModules`
- `GetDynamicSubModulesInfo()`: returns glob pattern `*Secrets.Shim.*.dll` + type predicate
- `GetService()`: returns loaded `ISecretsAbstract` provider
- `RegisterServices()`: registers loaded provider as `ISecretsAbstract` singleton
- **Blocked by:** Task 29
- **Blocks:** Task 32, 38

**Task 31: Update Secrets/Shim facade to include Plugin project**
- [ ] File: `src/ATAP.Utilities.Secrets/Shim/ATAP.Utilities.Secrets.Shim.csproj`
- Add ProjectReference to `Shim/Plugin/ATAP.Utilities.Secrets.Shim.Plugin.csproj`
- **Blocked by:** Tasks 28, 30
- **Blocks:** Task 32

**Task 32: Update Secrets facade to include Shim**
- [ ] File: `src/ATAP.Utilities.Secrets/ATAP.Utilities.Secrets.csproj`
- Add ProjectReference to `Shim/ATAP.Utilities.Secrets.Shim.csproj`
- Verify full facade builds: `dotnet build src/ATAP.Utilities.Secrets/ATAP.Utilities.Secrets.csproj`
- **Blocked by:** Tasks 13, 31
- **Blocks:** Task 38

---

#### Agent 5: Loader and Secrets Tests

**Task 33: Create unit tests for NativeAssemblyLoader**
- [ ] Create folder: `tests/ATAP.Utilities.Loader.UnitTests/`
- [ ] Create .csproj referencing Loader, Loader.Interfaces, xUnit, FluentAssertions
- [ ] Test `LoadAssembly()` with a real test DLL (build a tiny test assembly as part of test setup)
- [ ] Test `IsCollectible` is true by default
- [ ] Test `Unload()` releases the assembly (WeakReference.IsAlive == false after GC)
- [ ] Test shared types resolve from host context (load an assembly that references a shared interface)
- **Blocked by:** Tasks 1-4
- **Blocks:** nothing

**Task 34: Create unit tests for refactored Loader\<T\>**
- [ ] In: `tests/ATAP.Utilities.Loader.UnitTests/`
- [ ] Test `LoadExactlyOneInstanceOfITypeFromAssemblyGlob` with mock `IAssemblyLoader`
- [ ] Test exception when zero matching types found
- [ ] Test exception when multiple matching types found
- [ ] Test `LoadAndProcessZeroOrMoreInstanceOfITypeFromAssemblyGlob` with mock
- [ ] Test `ILoadDynamicSubModules` detection and sub-module loading
- **Blocked by:** Tasks 3, 4
- **Blocks:** nothing

**Task 35: Create unit tests for PluginFamilyBase\<T\>**
- [ ] In: `tests/ATAP.Utilities.Plugin.Model.UnitTests/` (or separate project)
- [ ] Test `DiscoverAsync()` finds matching DLLs in probing path
- [ ] Test `LoadAsync()` transitions plugin to Loaded state
- [ ] Test `UnloadAsync()` transitions and disposes
- [ ] Test hot-swap: load A, swap to B, verify A is unloaded and B is active
- [ ] Test error when loading non-existent pluginId
- **Blocked by:** Task 16
- **Blocks:** nothing

**Task 36: Create unit tests for Secrets interfaces and model**
- [ ] Create folder: `tests/ATAP.Utilities.Secrets.UnitTests/`
- [ ] Create .csproj referencing Secrets.Interfaces, Secrets.Model, xUnit, FluentAssertions
- [ ] Test `SecretMapping` record equality and property access
- [ ] Test `SecretsRouter` with multiple mock providers (first-non-null routing)
- [ ] Test `SecretsRouter.IsAvailable()` returns true if any provider is available
- [ ] Test `SecretsRouter` skips unavailable providers
- [ ] Test `SecretsProviderKind` enum values exist
- **Blocked by:** Tasks 10, 11
- **Blocks:** nothing

**Task 37: Create unit tests for BitwardenSecretsShim**
- [ ] Create folder: `tests/ATAP.Utilities.Secrets.Shim.Bitwarden.UnitTests/`
- [ ] Create .csproj referencing Secrets.Shim.Bitwarden, Secrets.Interfaces, xUnit, FluentAssertions, Moq
- [ ] Test `IsAvailable()` returns false when env var not set
- [ ] Test `IsAvailable()` returns true when env var is set
- [ ] Test `BitwardenSecretsOptions` defaults match `StringConstants`
- [ ] Test `ServiceCollectionExtensions.AddBitwardenSecrets()` registers `ISecretsAbstract`
- [ ] Test `ConfigurationBuilderExtensions.AddBitwardenSecrets()` adds source to builder
- [ ] Test `BitwardenConfigurationProvider.Load()` populates keys (mock the shim process call)
- [ ] Test `BitwardenConfigurationProvider.Load()` skips when not available
- **Blocked by:** Tasks 22-27
- **Blocks:** nothing

---

### Phase 4 -- Depends on Phase 3 (everything compiles)

---

#### Agent 4: PluginDemo Console App

**Task 38: Create ATAP.Console.PluginDemo .csproj**
- [ ] Create folder: `src/ATAP.Console.PluginDemo/`
- [ ] Create: `ATAP.Console.PluginDemo.csproj`
  - `<OutputType>Exe</OutputType>`
  - ProjectReferences: `Secrets.Interfaces`, `Secrets.Shim.Bitwarden` (static demo),
    `Loader`, `Loader.Interfaces`, `Plugin.Interfaces`, `Plugin.Model` (dynamic demo)
  - PackageReferences: `Microsoft.Extensions.Hosting`, `Microsoft.Extensions.Configuration.Json`
- **Blocked by:** Tasks 26, 27, 30, 32
- **Blocks:** Tasks 39, 40, 41, 42

**Task 39: Implement static consumption demo in PluginDemo**
- [ ] File: `src/ATAP.Console.PluginDemo/StaticDemo.cs`
- Per SecretsPluginArchitecture.md Section 11.1
- Use `builder.Configuration.AddBitwardenSecrets(mappings)` for config pipeline
- Use `builder.Services.AddBitwardenSecrets()` for DI
- Show consuming `ISecretsAbstract` from DI
- Print first 4 chars of retrieved secret + "****"
- **Blocked by:** Task 38
- **Blocks:** Task 42

**Task 40: Implement dynamic consumption demo in PluginDemo**
- [ ] File: `src/ATAP.Console.PluginDemo/DynamicDemo.cs`
- Per SecretsPluginArchitecture.md Section 11.2
- Use `NativeAssemblyLoader` + `Loader<ISecretsAbstract>`
- Use `DynamicGlobAndPredicate` to discover Bitwarden shim DLL
- Load, retrieve a secret, print masked value
- Demonstrate unload via `ILoadedAssemblyContext`
- **Blocked by:** Task 38
- **Blocks:** Task 42

**Task 41: Implement PluginFamily-based demo in PluginDemo**
- [ ] File: `src/ATAP.Console.PluginDemo/PluginFamilyDemo.cs`
- Use `PluginFamilyBase<ISecretsAbstract>` to discover, load, activate, use, deactivate, unload
- Demonstrate the full lifecycle state machine
- Show `IPluginData` observation if applicable
- **Blocked by:** Tasks 16, 38
- **Blocks:** Task 42

**Task 42: Implement Program.cs for PluginDemo**
- [ ] File: `src/ATAP.Console.PluginDemo/Program.cs`
- Menu or command-line args to select which demo to run: `--static`, `--dynamic`, `--family`
- Wire up `IHostBuilder` with logging
- Create `appsettings.json` with sample `Plugins` config section
- [ ] File: `src/ATAP.Console.PluginDemo/appsettings.json`
- **Blocked by:** Tasks 39, 40, 41
- **Blocks:** nothing

---

#### Agent 5: Integration Tests

**Task 43: Create integration test for static Bitwarden consumption**
- [ ] Create folder: `tests/ATAP.Utilities.Secrets.IntegrationTests/`
- [ ] Create .csproj with conditional test skip when `BW_SESSION` not set
- [ ] Test full pipeline: `AddBitwardenSecrets()` -> `IConfiguration` -> retrieve value
- [ ] Mark with `[Trait("Category", "Integration")]` for CI filtering
- **Blocked by:** Tasks 22-27
- **Blocks:** nothing

**Task 44: Create integration test for dynamic loading of Bitwarden shim**
- [ ] In: `tests/ATAP.Utilities.Secrets.IntegrationTests/`
- [ ] Build Bitwarden shim DLL, copy to a test Plugins folder
- [ ] Use `Loader<ISecretsAbstract>` to dynamically load it
- [ ] Verify `IsAvailable()` and `GetSecretAsync()` work through dynamic loading
- [ ] Verify `Unload()` releases the assembly (WeakReference check)
- **Blocked by:** Tasks 3, 22, 30
- **Blocks:** nothing

**Task 45: Create integration test for PluginFamily hot-swap**
- [ ] In: `tests/ATAP.Utilities.Plugin.IntegrationTests/` (or use existing test project)
- [ ] Create two trivial test plugin DLLs (TestPluginA, TestPluginB) implementing a shared interface
- [ ] Test `PluginFamilyBase<T>` discover -> load A -> activate -> deactivate -> unload -> load B -> activate
- [ ] Verify A's ALC is collected after unload
- **Blocked by:** Task 16
- **Blocks:** nothing

**Task 46: Create integration test for PluginDemo console app**
- [ ] Run `ATAP.Console.PluginDemo --static` and verify exit code 0
- [ ] Run `ATAP.Console.PluginDemo --dynamic` and verify exit code 0
- [ ] Can be a simple process-launch test or a test host
- **Blocked by:** Task 42
- **Blocks:** nothing

---

### Phase 5 -- Cleanup and Future Work

---

#### Agent 1: Cleanup

**Task 47: Add solution file entries for all new projects**
- [ ] Add to the `.sln` file: all `ATAP.Utilities.Secrets.*`, `ATAP.Utilities.Plugin.*`, `ATAP.Console.PluginDemo`, and all new test projects
- [ ] Verify `dotnet build ATAP.Utilities.sln` compiles everything
- **Blocked by:** All Phase 3 tasks
- **Blocks:** nothing

**Task 48: Add `[Obsolete]` attributes to old secrets implementations**
- [ ] In `src/ATAP.Utilities.Configuration.Secrets/`: add `[Obsolete("Use ATAP.Utilities.Secrets instead")]` to `ISecretProvider`, `SecretProvidersBuilder`, etc.
- [ ] In `src/ATAP.Utilities.Configuration/Secrets/Shims/`: add `[Obsolete]` to `IConfigurationSecrets`, `IConfigurationSecretsShim`, `BitwardenSecretsShim`, etc.
- [ ] Do NOT delete these yet -- consumers may still reference them
- **Blocked by:** Tasks 22-32 (new implementation must exist)
- **Blocks:** nothing

---

#### Agent 3: PowerShell Module (Bonus)

**Task 49: Create PowerShell module manifest and script module**
- [ ] Create folder: `src/ATAP.Utilities.Plugin.Powershell/`
- [ ] Create: `ATAP.Utilities.Plugin.psd1` (module manifest)
  - RequiredAssemblies: `ATAP.Utilities.Plugin.Interfaces.dll`, `ATAP.Utilities.Loader.dll`, etc.
- [ ] Create: `ATAP.Utilities.Plugin.psm1` (script module, dot-sources cmdlets)
- Per GenericPluginArchitecture.md Section 12
- **Blocked by:** Tasks 16, 30 (full Plugin + Secrets must work)
- **Blocks:** Task 50

**Task 50: Create PowerShell cmdlet wrappers**
- [ ] Create: `Cmdlets/New-PluginFamily.ps1`
- [ ] Create: `Cmdlets/Get-PluginMetadata.ps1`
- [ ] Create: `Cmdlets/Import-Plugin.ps1` (wraps LoadAsync + InitializeAsync + ActivateAsync)
- [ ] Create: `Cmdlets/Remove-Plugin.ps1` (wraps DeactivateAsync + UnloadAsync)
- [ ] Create: `FamilySpecific/Get-Secret.ps1` (convenience wrapper for Secrets family)
- Per GenericPluginArchitecture.md Sections 12.2, 12.3
- **Blocked by:** Task 49
- **Blocks:** nothing

---

## Summary Matrix

| Task | Agent | Phase | Depends On | Description |
|------|-------|-------|-----------|-------------|
| 1 | 1 | 0 | -- | Remove McMaster from Loader .csproj |
| 2 | 1 | 0 | 1 | Add IAssemblyLoader to Loader\<T\> constructor |
| 3 | 1 | 0 | 2 | Rewrite LoadExactlyOne to use IAssemblyLoader |
| 4 | 1 | 0 | 2 | Rewrite LoadAndProcessZeroOrMore to use IAssemblyLoader |
| 5 | 1 | 0 | 3,4 | Delete dead code from Loader.cs |
| 6 | 2 | 0 | -- | Secrets Interfaces .csproj + ISecretsAbstract |
| 7 | 2 | 0 | 6 | ISecretsOptionsAbstract + ISecretsConfigurableAbstract |
| 8 | 2 | 0 | 6 | ISecretsPluginShim |
| 9 | 2 | 0 | -- | Secrets Enumerations .csproj + SecretsProviderKind |
| 10 | 2 | 0 | 6,7 | Secrets Model .csproj + abstract base classes |
| 11 | 2 | 0 | 10 | SecretMapping + SecretsRouter |
| 12 | 2 | 0 | -- | Secrets StringConstants .csproj |
| 13 | 2 | 0 | 6,9,10,12 | Secrets facade .csproj |
| 14 | 5 | 0 | -- | Tests: Plugin.Interfaces enums/args |
| 15 | 5 | 0 | -- | Tests: Plugin.Model classes |
| 16 | 1 | 1 | 3,4 | Implement PluginFamilyBase\<T\> |
| 17 | 1 | 1 | 16 | Update Plugin.Model .csproj references |
| 18 | 1 | 1 | 1-4 | Flesh out LoaderOptions |
| 19 | 1 | 1 | 3,4 | Add LoadAndRegister\<T\> method |
| 20 | 3 | 2 | 6,7,10,12 | Shim/Bitwarden .csproj |
| 21 | 3 | 2 | 20 | BitwardenSecretsOptions |
| 22 | 3 | 2 | 10,21 | BitwardenSecretsShim |
| 23 | 3 | 2 | 7,21 | SecretsOptions wrapper |
| 24 | 3 | 2 | 21,22 | BitwardenConfigurationSource |
| 25 | 3 | 2 | 22,24 | BitwardenConfigurationProvider |
| 26 | 3 | 2 | 22 | ServiceCollectionExtensions |
| 27 | 3 | 2 | 24,25 | ConfigurationBuilderExtensions |
| 28 | 4 | 2 | 6-12 | Secrets Shim facade .csproj |
| 29 | 4 | 3 | 6,8,16 | Secrets Shim/Plugin .csproj |
| 30 | 4 | 3 | 29 | SecretsPluginShim implementation |
| 31 | 4 | 3 | 28,30 | Update Shim facade for Plugin project |
| 32 | 4 | 3 | 13,31 | Update Secrets facade for Shim |
| 33 | 5 | 3 | 1-4 | Tests: NativeAssemblyLoader |
| 34 | 5 | 3 | 3,4 | Tests: Refactored Loader\<T\> |
| 35 | 5 | 3 | 16 | Tests: PluginFamilyBase\<T\> |
| 36 | 5 | 3 | 10,11 | Tests: Secrets interfaces + model |
| 37 | 5 | 3 | 22-27 | Tests: BitwardenSecretsShim |
| 38 | 4 | 4 | 26,27,30,32 | PluginDemo .csproj |
| 39 | 4 | 4 | 38 | Static consumption demo |
| 40 | 4 | 4 | 38 | Dynamic consumption demo |
| 41 | 4 | 4 | 16,38 | PluginFamily-based demo |
| 42 | 4 | 4 | 39,40,41 | Program.cs + appsettings.json |
| 43 | 5 | 4 | 22-27 | Integration test: static Bitwarden |
| 44 | 5 | 4 | 3,22,30 | Integration test: dynamic loading |
| 45 | 5 | 4 | 16 | Integration test: hot-swap |
| 46 | 5 | 4 | 42 | Integration test: PluginDemo app |
| 47 | 1 | 5 | Phase 3 | Solution file entries |
| 48 | 1 | 5 | 22-32 | Deprecate old secrets code |
| 49 | 3 | 5 | 16,30 | PowerShell module manifest |
| 50 | 3 | 5 | 49 | PowerShell cmdlet wrappers |

---

## Agent Workload at a Glance

| Agent | Phase 0 | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Total |
|-------|---------|---------|---------|---------|---------|---------|-------|
| 1 | 5 | 4 | -- | -- | -- | 2 | **11** |
| 2 | 8 | -- | -- | -- | -- | -- | **8** |
| 3 | -- | -- | 8 | -- | -- | 2 | **10** |
| 4 | -- | -- | 1 | 4 | 5 | -- | **10** |
| 5 | 2 | -- | -- | 5 | 4 | -- | **11** |
| **Phase total** | **15** | **4** | **9** | **9** | **9** | **4** | **50** |
