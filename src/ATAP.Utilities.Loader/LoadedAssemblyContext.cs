using System;
using System.Reflection;
using System.Runtime.Loader;

namespace ATAP.Utilities.Loader {
  /// <summary>
  /// Wraps a loaded assembly and its CollectibleAssemblyLoadContext.
  /// Provides unload capability and WeakReference tracking for GC verification.
  /// </summary>
  public class LoadedAssemblyContext : ILoadedAssemblyContext {
    private readonly AssemblyLoadContext _context;
    private bool _disposed;

    public LoadedAssemblyContext(AssemblyLoadContext context, Assembly loadedAssembly) {
      _context = context;
      LoadedAssembly = loadedAssembly;
      IsCollectible = context.IsCollectible;
      WeakReference = new WeakReference(context);
    }

    public Assembly LoadedAssembly { get; }
    public bool IsCollectible { get; }
    public WeakReference WeakReference { get; }

    public void Unload() {
      if (_context.IsCollectible) {
        _context.Unload();
      }
    }

    public void Dispose() {
      if (!_disposed) {
        Unload();
        _disposed = true;
      }
    }
  }
}
