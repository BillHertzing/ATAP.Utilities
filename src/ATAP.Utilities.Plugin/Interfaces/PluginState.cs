namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// Lifecycle state of a plugin instance.
  /// </summary>
  public enum PluginState {
    /// <summary>Assembly found on disk via glob discovery.</summary>
    Discovered,
    /// <summary>Assembly loaded into a collectible AssemblyLoadContext.</summary>
    Loaded,
    /// <summary>Plugin has read its configuration and built internal state.</summary>
    Configured,
    /// <summary>Plugin is serving requests and exposing IPluginData.</summary>
    Active,
    /// <summary>Plugin is flushing state and detaching event handlers.</summary>
    Deactivating,
    /// <summary>AssemblyLoadContext unloaded, sensitive data zeroed.</summary>
    Unloaded
  }
}
