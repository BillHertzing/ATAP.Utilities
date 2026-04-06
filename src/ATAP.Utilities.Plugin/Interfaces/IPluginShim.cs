using Microsoft.Extensions.DependencyInjection;

namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// Generic plugin shim contract. TFamilyInterface is the family's abstract interface
  /// (e.g. ISecretsAbstract, ISerializerAbstract).
  /// Combines metadata and lifecycle with service access and DI registration.
  /// </summary>
  /// <typeparam name="TFamilyInterface">The plugin family's abstract interface type.</typeparam>
  public interface IPluginShim<TFamilyInterface> : IPluginMetadata, IPluginLifecycle {
    /// <summary>Returns the concrete service implementing TFamilyInterface.</summary>
    TFamilyInterface GetService();

    /// <summary>Registers the plugin's services into the host DI container.</summary>
    void RegisterServices(IServiceCollection services);
  }
}
