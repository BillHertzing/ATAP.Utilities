using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// Manages a plugin family: discovery, loading, activation, and unloading.
  /// A plugin family is a group of interchangeable implementations behind a shared interface.
  /// </summary>
  /// <typeparam name="TInterface">The family's abstract interface type.</typeparam>
  public interface IPluginFamily<TInterface> {
    /// <summary>Human-readable family name (e.g. "Secrets", "Serializer").</summary>
    string FamilyName { get; }

    /// <summary>All plugins found during the most recent DiscoverAsync call.</summary>
    IReadOnlyList<IPluginMetadata> DiscoveredPlugins { get; }

    /// <summary>The currently active plugin, or null if none is loaded.</summary>
    IPluginShim<TInterface>? ActivePlugin { get; }

    /// <summary>
    /// Discovers available plugins by scanning configured probing paths.
    /// </summary>
    Task DiscoverAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Loads and initializes a specific plugin by its PluginId.
    /// </summary>
    Task<IPluginShim<TInterface>> LoadAsync(string pluginId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Deactivates and unloads a plugin, releasing its AssemblyLoadContext for GC.
    /// </summary>
    Task UnloadAsync(string pluginId, CancellationToken cancellationToken = default);
  }
}
