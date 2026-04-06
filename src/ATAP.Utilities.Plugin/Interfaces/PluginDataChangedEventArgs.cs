using System;

namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// Event args for plugin data changes. Contains deep-copied values
  /// to prevent cross-AssemblyLoadContext reference leaking.
  /// </summary>
  public class PluginDataChangedEventArgs : EventArgs {
    /// <summary>The data key that changed.</summary>
    public string Key { get; init; } = string.Empty;

    /// <summary>Deep-copied previous value, or null if added.</summary>
    public object? OldValue { get; init; }

    /// <summary>Deep-copied new value, or null if removed.</summary>
    public object? NewValue { get; init; }

    /// <summary>The kind of change.</summary>
    public PluginDataChangeKind ChangeKind { get; init; }
  }
}
