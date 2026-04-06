using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// Abstract base class for plugin shims. Provides lifecycle state machine
  /// and common infrastructure. Concrete shims override GetService() and RegisterServices().
  /// </summary>
  /// <typeparam name="TFamilyInterface">The plugin family's abstract interface type.</typeparam>
  public abstract class PluginShimBase<TFamilyInterface> : IPluginShim<TFamilyInterface> {
    private PluginState _state = PluginState.Discovered;

    public PluginState State => _state;

    public abstract string PluginId { get; }
    public abstract string DisplayName { get; }
    public abstract Version Version { get; }
    public abstract Type FamilyInterface { get; }
    public abstract TFamilyInterface GetService();
    public abstract void RegisterServices(IServiceCollection services);

    public virtual Task InitializeAsync(IConfiguration pluginConfiguration, CancellationToken cancellationToken = default) {
      ValidateTransition(PluginState.Loaded, PluginState.Configured);
      _state = PluginState.Configured;
      return Task.CompletedTask;
    }

    public virtual Task ActivateAsync(CancellationToken cancellationToken = default) {
      ValidateTransition(PluginState.Configured, PluginState.Active);
      _state = PluginState.Active;
      return Task.CompletedTask;
    }

    public virtual Task DeactivateAsync(CancellationToken cancellationToken = default) {
      ValidateTransition(PluginState.Active, PluginState.Deactivating);
      _state = PluginState.Deactivating;
      return Task.CompletedTask;
    }

    public virtual Task UnloadAsync(CancellationToken cancellationToken = default) {
      ValidateTransition(PluginState.Deactivating, PluginState.Unloaded);
      _state = PluginState.Unloaded;
      return Task.CompletedTask;
    }

    /// <summary>
    /// Sets the state to Loaded. Called by the Loader after assembly loading.
    /// </summary>
    public void MarkLoaded() {
      _state = PluginState.Loaded;
    }

    private void ValidateTransition(PluginState expectedFrom, PluginState to) {
      if (_state != expectedFrom) {
        throw new InvalidOperationException(
          $"Cannot transition to {to} from {_state}. Expected state: {expectedFrom}.");
      }
    }
  }
}
