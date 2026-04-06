using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.Loader;
using System.Threading.Tasks;

using ATAP.Utilities.FileIO;

namespace ATAP.Utilities.Loader {
  public interface IDynamicGlobAndPredicate {
    Glob Glob { get; }
    Predicate<Type> Predicate { get; }
  }

  public interface IDynamicShimNameAndNamespaceConfigRootKeyAndDefaultValue {
    string DynamicShimNameConfigRootKey { get; }
    string DynamicShimNameConfigDefault { get; }
    string DynamicShimNamespaceConfigRootKey { get; }
    string DynamicShimNamespaceConfigurationDefault { get; }
  }

  public interface IDynamicSubModulesInfo {
    IDynamicGlobAndPredicate DynamicGlobAndPredicate { get; }
    Action<object> Function { get; }
  }

  /// <summary>
  /// Interface for types that have dynamic submodules to discover and load.
  /// </summary>
  public interface ILoadDynamicSubModules {
    IDictionary<Type, IDynamicSubModulesInfo> GetDynamicSubModulesInfo();
  }

  /// <summary>
  /// Represents a loaded assembly in an isolated context.
  /// Tracks the AssemblyLoadContext and provides unload capability.
  /// </summary>
  public interface ILoadedAssemblyContext : IDisposable {
    /// <summary>The loaded assembly.</summary>
    Assembly LoadedAssembly { get; }

    /// <summary>Whether the underlying AssemblyLoadContext is collectible.</summary>
    bool IsCollectible { get; }

    /// <summary>WeakReference for verifying GC after unload.</summary>
    WeakReference WeakReference { get; }

    /// <summary>Unloads the AssemblyLoadContext, releasing all loaded assemblies.</summary>
    void Unload();
  }

  /// <summary>
  /// Abstraction over the mechanism that loads assemblies into isolated contexts.
  /// Default implementation uses native AssemblyLoadContext with isCollectible: true.
  /// </summary>
  public interface IAssemblyLoader {
    /// <summary>
    /// Loads an assembly from the specified path into an isolated context.
    /// </summary>
    /// <param name="assemblyPath">Full path to the assembly file.</param>
    /// <param name="sharedTypes">Types that should resolve from the host's default context.</param>
    /// <param name="isCollectible">Whether the context should be collectible (enables GC after unload).</param>
    ILoadedAssemblyContext LoadAssembly(string assemblyPath, Type[] sharedTypes, bool isCollectible = true);

    /// <summary>
    /// Unloads a previously loaded assembly context.
    /// </summary>
    Task UnloadAsync(ILoadedAssemblyContext context);
  }

}
