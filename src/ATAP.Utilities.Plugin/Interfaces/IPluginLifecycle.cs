using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// Lifecycle management for a loaded plugin instance.
  /// State transitions: Discovered -> Loaded -> Configured -> Active -> Deactivating -> Unloaded
  /// </summary>
  public interface IPluginLifecycle {
    /// <summary>Current lifecycle state.</summary>
    PluginState State { get; }

    /// <summary>
    /// Initialize the plugin with its configuration section.
    /// Transitions: Loaded -> Configured.
    /// </summary>
    Task InitializeAsync(IConfiguration pluginConfiguration, CancellationToken cancellationToken = default);

    /// <summary>
    /// Activate the plugin for use. Transitions: Configured -> Active.
    /// </summary>
    Task ActivateAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Begin deactivation: flush state, detach event handlers.
    /// Transitions: Active -> Deactivating.
    /// </summary>
    Task DeactivateAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Unload the plugin: zero sensitive data, release ALC for GC.
    /// Transitions: Deactivating -> Unloaded.
    /// </summary>
    Task UnloadAsync(CancellationToken cancellationToken = default);
  }
}
