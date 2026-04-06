using System;
using System.Threading.Tasks;

namespace ATAP.Utilities.Loader {
  /// <summary>
  /// Default IAssemblyLoader implementation using native .NET AssemblyLoadContext.
  /// Creates a CollectibleAssemblyLoadContext per loaded assembly with shared type resolution.
  /// Replaces the McMaster.NETCore.Plugins hard dependency.
  /// </summary>
  public class NativeAssemblyLoader : IAssemblyLoader {
    public ILoadedAssemblyContext LoadAssembly(string assemblyPath, Type[] sharedTypes, bool isCollectible = true) {
      var context = new CollectibleAssemblyLoadContext(assemblyPath, sharedTypes, isCollectible);
      var assembly = context.LoadFromAssemblyPath(assemblyPath);
      return new LoadedAssemblyContext(context, assembly);
    }

    public Task UnloadAsync(ILoadedAssemblyContext context) {
      context.Unload();
      return Task.CompletedTask;
    }
  }
}
