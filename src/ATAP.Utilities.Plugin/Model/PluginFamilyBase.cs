using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.Loader;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Plugin
{
  /// <summary>
  /// Abstract base class for plugin families. Provides glob-based assembly discovery,
  /// collectible AssemblyLoadContext isolation, and load/unload coordination.
  /// Concrete families supply the probe directory, family name, and shim factory.
  /// </summary>
  /// <typeparam name="TInterface">The plugin family's abstract interface type.</typeparam>
  public abstract class PluginFamilyBase<TInterface> : IPluginFamily<TInterface>, IDisposable
  {
    private readonly List<IPluginMetadata> _discovered = new();
    private readonly ConcurrentDictionary<string, (IPluginShim<TInterface> Shim, LoadedPluginContext Context)> _loaded = new();
    private IPluginShim<TInterface>? _activePlugin;
    private readonly SemaphoreSlim _swapLock = new(1, 1);
    private bool _disposed;

    /// <inheritdoc />
    public abstract string FamilyName { get; }

    /// <summary>
    /// Root directory (or colon-separated list) to search for plugin assemblies.
    /// Resolved from configuration key <c>PluginDirectory</c> by default.
    /// </summary>
    protected abstract string ProbeDirectory { get; }

    /// <summary>
    /// Glob pattern relative to <see cref="ProbeDirectory"/> to locate candidate assemblies.
    /// Defaults to <c>**/*.dll</c>.
    /// </summary>
    protected virtual string AssemblyGlob => "**/*.dll";

    /// <summary>
    /// Shared types whose resolution should fall through to the host's default ALC.
    /// Must include at minimum the Interfaces assembly type.
    /// </summary>
    protected abstract Type[] SharedTypes { get; }

    /// <inheritdoc />
    public IReadOnlyList<IPluginMetadata> DiscoveredPlugins => _discovered.AsReadOnly();

    /// <inheritdoc />
    public IPluginShim<TInterface>? ActivePlugin => _activePlugin;

    /// <inheritdoc />
    public Task DiscoverAsync(CancellationToken cancellationToken = default)
    {
      _discovered.Clear();

      var dirs = ProbeDirectory
        .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

      foreach (var dir in dirs)
      {
        if (!Directory.Exists(dir))
        {
          continue;
        }

        var candidates = Directory.EnumerateFiles(dir, "*.dll", SearchOption.AllDirectories);
        foreach (var assemblyPath in candidates)
        {
          cancellationToken.ThrowIfCancellationRequested();
          var metadata = TryLoadMetadata(assemblyPath);
          if (metadata is not null && IsValidFamilyMember(metadata))
          {
            _discovered.Add(metadata);
          }
        }
      }

      return Task.CompletedTask;
    }

    /// <inheritdoc />
    public async Task<IPluginShim<TInterface>> LoadAsync(
      string pluginId,
      CancellationToken cancellationToken = default)
    {
      if (_loaded.TryGetValue(pluginId, out var existing))
      {
        return existing.Shim;
      }

      var metadata = _discovered.FirstOrDefault(m => m.PluginId == pluginId)
        ?? throw new InvalidOperationException(
          $"Plugin '{pluginId}' was not found in the discovered plugins for family '{FamilyName}'.");

      var assemblyPath = GetAssemblyPath(metadata);
      var context = new LoadedPluginContext(assemblyPath, SharedTypes);
      var shim = CreateShim(context.LoadedAssembly, metadata);

      if (shim is PluginShimBase<TInterface> shimBase)
      {
        shimBase.MarkLoaded();
      }

      if (!_loaded.TryAdd(pluginId, (shim, context)))
      {
        // Race: another thread loaded it first; discard and return theirs
        context.Dispose();
        return _loaded[pluginId].Shim;
      }

      return shim;
    }

    /// <inheritdoc />
    public async Task UnloadAsync(string pluginId, CancellationToken cancellationToken = default)
    {
      if (!_loaded.TryGetValue(pluginId, out var entry))
      {
        return;
      }

      await _swapLock.WaitAsync(cancellationToken).ConfigureAwait(false);
      try
      {
        if (ReferenceEquals(_activePlugin, entry.Shim))
        {
          await entry.Shim.DeactivateAsync(cancellationToken).ConfigureAwait(false);
          _activePlugin = null;
        }

        await entry.Shim.UnloadAsync(cancellationToken).ConfigureAwait(false);
        entry.Context.Dispose();
        _loaded.TryRemove(pluginId, out _);
      }
      finally
      {
        _swapLock.Release();
      }
    }

    /// <summary>
    /// Activates a loaded plugin as the active plugin for this family.
    /// If another plugin is currently active it is deactivated first (hot-swap).
    /// </summary>
    public async Task ActivateAsync(
      string pluginId,
      IConfiguration pluginConfiguration,
      CancellationToken cancellationToken = default)
    {
      if (!_loaded.TryGetValue(pluginId, out var entry))
      {
        await LoadAsync(pluginId, cancellationToken).ConfigureAwait(false);
        entry = _loaded[pluginId];
      }

      await _swapLock.WaitAsync(cancellationToken).ConfigureAwait(false);
      try
      {
        if (_activePlugin is not null && !ReferenceEquals(_activePlugin, entry.Shim))
        {
          await _activePlugin.DeactivateAsync(cancellationToken).ConfigureAwait(false);
          _activePlugin = null;
        }

        if (entry.Shim.State == PluginState.Loaded)
        {
          await entry.Shim.InitializeAsync(pluginConfiguration, cancellationToken).ConfigureAwait(false);
        }

        await entry.Shim.ActivateAsync(cancellationToken).ConfigureAwait(false);
        _activePlugin = entry.Shim;
      }
      finally
      {
        _swapLock.Release();
      }
    }

    // ─── Extension points ─────────────────────────────────────────────────────

    /// <summary>
    /// Examines a candidate assembly path and extracts plugin metadata.
    /// Returns <c>null</c> if the assembly is not a valid plugin for this family.
    /// Default implementation uses assembly-level attributes; override for alternatives.
    /// </summary>
    protected virtual IPluginMetadata? TryLoadMetadata(string assemblyPath)
    {
      try
      {
        // Load into a throw-away context to read metadata only
        using var probe = new AssemblyNameProbeContext(assemblyPath);
        return probe.TryExtractMetadata(typeof(TInterface));
      }
      catch
      {
        return null;
      }
    }

    /// <summary>
    /// Returns <c>true</c> if the discovered metadata should be included in this
    /// family. Override to filter by naming convention, version range, etc.
    /// Default: the metadata's <see cref="IPluginMetadata.FamilyInterface"/> must
    /// assignable from <typeparamref name="TInterface"/>.
    /// </summary>
    protected virtual bool IsValidFamilyMember(IPluginMetadata metadata)
    {
      return typeof(TInterface).IsAssignableFrom(metadata.FamilyInterface);
    }

    /// <summary>
    /// Returns the file system path to the assembly for the given metadata.
    /// Override if discovery stores paths in a side-channel (e.g., a registry).
    /// Default: looks for a file named <c>{metadata.PluginId}.dll</c> in probe directories.
    /// </summary>
    protected virtual string GetAssemblyPath(IPluginMetadata metadata)
    {
      var dirs = ProbeDirectory
        .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

      foreach (var dir in dirs)
      {
        var candidates = Directory.EnumerateFiles(dir, "*.dll", SearchOption.AllDirectories);
        foreach (var path in candidates)
        {
          if (Path.GetFileNameWithoutExtension(path)
              .Equals(metadata.PluginId, StringComparison.OrdinalIgnoreCase))
          {
            return path;
          }
        }
      }

      throw new FileNotFoundException(
        $"Assembly file for plugin '{metadata.PluginId}' was not found in any probe directory.");
    }

    /// <summary>
    /// Creates a shim instance from the loaded assembly.
    /// Override to customise instantiation (e.g., constructor injection).
    /// </summary>
    protected virtual IPluginShim<TInterface> CreateShim(Assembly assembly, IPluginMetadata metadata)
    {
      var shimType = assembly.GetTypes()
        .FirstOrDefault(t =>
          !t.IsAbstract &&
          typeof(IPluginShim<TInterface>).IsAssignableFrom(t))
        ?? throw new InvalidOperationException(
          $"No concrete IPluginShim<{typeof(TInterface).Name}> type found in assembly for plugin '{metadata.PluginId}'.");

      var instance = Activator.CreateInstance(shimType)
        ?? throw new InvalidOperationException(
          $"Activator.CreateInstance returned null for plugin '{metadata.PluginId}'.");

      return (IPluginShim<TInterface>)instance;
    }

    // ─── Disposal ─────────────────────────────────────────────────────────────

    public void Dispose()
    {
      Dispose(true);
      GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing)
    {
      if (_disposed)
      {
        return;
      }

      if (disposing)
      {
        foreach (var entry in _loaded.Values)
        {
          try { entry.Context.Dispose(); }
          catch { /* best-effort */ }
        }

        _loaded.Clear();
        _swapLock.Dispose();
      }

      _disposed = true;
    }

    // ─── Inner helpers ────────────────────────────────────────────────────────

    /// <summary>
    /// Lightweight collectible ALC used to load a single plugin assembly in isolation.
    /// </summary>
    private sealed class LoadedPluginContext : IDisposable
    {
      private readonly CollectiblePluginALC _alc;
      private bool _disposed;

      public Assembly LoadedAssembly { get; }

      public LoadedPluginContext(string assemblyPath, Type[] sharedTypes)
      {
        _alc = new CollectiblePluginALC(assemblyPath, sharedTypes);
        LoadedAssembly = _alc.LoadFromAssemblyPath(assemblyPath);
      }

      public void Dispose()
      {
        if (_disposed)
        {
          return;
        }

        _alc.Unload();
        _disposed = true;
      }
    }

    /// <summary>
    /// Standard collectible AssemblyLoadContext.
    /// Shared type assemblies fall through to the host's default context.
    /// </summary>
    private sealed class CollectiblePluginALC : AssemblyLoadContext
    {
      private readonly AssemblyDependencyResolver _resolver;
      private readonly HashSet<string> _sharedAssemblyNames;

      public CollectiblePluginALC(string pluginAssemblyPath, Type[] sharedTypes)
        : base(isCollectible: true)
      {
        _resolver = new AssemblyDependencyResolver(pluginAssemblyPath);
        _sharedAssemblyNames = sharedTypes
          .Select(t => t.Assembly.GetName().Name!)
          .ToHashSet(StringComparer.OrdinalIgnoreCase);
      }

      protected override Assembly? Load(AssemblyName assemblyName)
      {
        // Shared types resolve from the host's default context
        if (_sharedAssemblyNames.Contains(assemblyName.Name!))
        {
          return null;
        }

        var resolvedPath = _resolver.ResolveAssemblyToPath(assemblyName);
        return resolvedPath is not null ? LoadFromAssemblyPath(resolvedPath) : null;
      }
    }

    /// <summary>
    /// Probe context: loads an assembly read-only to extract IPluginMetadata-derived
    /// attributes, then discards the ALC. Avoids polluting the default ALC with
    /// non-validated assemblies.
    /// </summary>
    private sealed class AssemblyNameProbeContext : IDisposable
    {
      private readonly AssemblyLoadContext _probeAlc;
      private readonly Assembly _assembly;
      private bool _disposed;

      public AssemblyNameProbeContext(string assemblyPath)
      {
        _probeAlc = new AssemblyLoadContext(name: null, isCollectible: true);
        _assembly = _probeAlc.LoadFromAssemblyPath(assemblyPath);
      }

      /// <summary>
      /// Extracts metadata from a <see cref="PluginMetadataAttribute"/> if present.
      /// </summary>
      public IPluginMetadata? TryExtractMetadata(Type familyInterface)
      {
        var attr = _assembly
          .GetCustomAttributes<PluginMetadataAttribute>()
          .FirstOrDefault();

        if (attr is null)
        {
          return null;
        }

        return new SimplePluginMetadata(
          attr.PluginId,
          attr.DisplayName,
          attr.Version,
          attr.FamilyInterfaceTypeName is not null
            ? Type.GetType(attr.FamilyInterfaceTypeName) ?? familyInterface
            : familyInterface);
      }

      public void Dispose()
      {
        if (_disposed)
        {
          return;
        }

        _probeAlc.Unload();
        _disposed = true;
      }
    }

    /// <summary>
    /// Immutable metadata record used during discovery before a shim is loaded.
    /// </summary>
    private sealed class SimplePluginMetadata : IPluginMetadata
    {
      public SimplePluginMetadata(string pluginId, string displayName, Version version, Type familyInterface)
      {
        PluginId = pluginId;
        DisplayName = displayName;
        Version = version;
        FamilyInterface = familyInterface;
      }

      public string PluginId { get; }
      public string DisplayName { get; }
      public Version Version { get; }
      public Type FamilyInterface { get; }
    }
  }

  // ─── Assembly-level attribute for plugin self-registration ──────────────────

  /// <summary>
  /// Assembly-level attribute that plugin assemblies use to declare their metadata.
  /// Discovered during <see cref="PluginFamilyBase{TInterface}.DiscoverAsync"/> before
  /// the shim is instantiated.
  /// </summary>
  [AttributeUsage(AttributeTargets.Assembly)]
  public sealed class PluginMetadataAttribute : Attribute
  {
    public string PluginId { get; }
    public string DisplayName { get; }
    public Version Version { get; }

    /// <summary>
    /// Optional assembly-qualified name of the family interface this plugin implements.
    /// If null the probe context's <c>familyInterface</c> parameter is used.
    /// </summary>
    public string? FamilyInterfaceTypeName { get; set; }

    public PluginMetadataAttribute(string pluginId, string displayName, string version)
    {
      PluginId = pluginId;
      DisplayName = displayName;
      Version = System.Version.Parse(version);
    }
  }
}
