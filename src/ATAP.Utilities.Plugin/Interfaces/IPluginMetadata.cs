using System;

namespace ATAP.Utilities.Plugin {
  /// <summary>
  /// Metadata describing a discovered or loaded plugin.
  /// </summary>
  public interface IPluginMetadata {
    /// <summary>Reverse-DNS identifier, e.g. "atap.secrets.bitwarden".</summary>
    string PluginId { get; }

    /// <summary>Human-readable display name.</summary>
    string DisplayName { get; }

    /// <summary>Plugin assembly version.</summary>
    Version Version { get; }

    /// <summary>The family interface this plugin implements (e.g. typeof(ISecretsAbstract)).</summary>
    Type FamilyInterface { get; }
  }
}
