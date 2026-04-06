using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.Loader;

namespace ATAP.Utilities.Loader {
  /// <summary>
  /// AssemblyLoadContext subclass that supports collectible (unloadable) assemblies.
  /// Uses AssemblyDependencyResolver for .deps.json resolution and routes
  /// shared types back to the host's default AssemblyLoadContext.
  /// </summary>
  internal class CollectibleAssemblyLoadContext : AssemblyLoadContext {
    private readonly AssemblyDependencyResolver _resolver;
    private readonly HashSet<string> _sharedTypeAssemblyNames;

    public CollectibleAssemblyLoadContext(string pluginPath, Type[] sharedTypes, bool isCollectible)
        : base(isCollectible: isCollectible) {
      _resolver = new AssemblyDependencyResolver(pluginPath);
      _sharedTypeAssemblyNames = sharedTypes
          .Select(t => t.Assembly.GetName().Name!)
          .ToHashSet(StringComparer.OrdinalIgnoreCase);
    }

    protected override Assembly? Load(AssemblyName assemblyName) {
      // Shared types resolve from the host's default context (return null = fallback)
      if (_sharedTypeAssemblyNames.Contains(assemblyName.Name!))
        return null;

      string? assemblyPath = _resolver.ResolveAssemblyToPath(assemblyName);
      return assemblyPath != null ? LoadFromAssemblyPath(assemblyPath) : null;
    }

    protected override IntPtr LoadUnmanagedDll(string unmanagedDllName) {
      string? libraryPath = _resolver.ResolveUnmanagedDllToPath(unmanagedDllName);
      return libraryPath != null ? LoadUnmanagedDllFromPath(libraryPath) : IntPtr.Zero;
    }
  }
}
