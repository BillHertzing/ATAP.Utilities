using System;
using System.Collections.Generic;

namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// Read-only, observable view of plugin internal data.
  /// Wraps ConcurrentObservableDictionary with deep-copy semantics across ALC boundaries.
  /// Formalizes the Ace-era "plugin Data object" pattern into a standard interface.
  /// </summary>
  public interface IPluginData {
    /// <summary>
    /// Read-only snapshot of the plugin's exposed data.
    /// Values are deep-copied to prevent cross-ALC reference leaking.
    /// </summary>
    IReadOnlyDictionary<string, object> DataStore { get; }

    /// <summary>
    /// Observable stream of data change notifications.
    /// Each event contains deep-copied old and new values.
    /// </summary>
    IObservable<PluginDataChangedEventArgs> DataChanged { get; }
  }
}
