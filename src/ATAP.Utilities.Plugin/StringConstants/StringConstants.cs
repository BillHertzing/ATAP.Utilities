namespace ATAP.Utilities.Plugin {
  public static class StringConstants {
    #region Plugin configuration section
    /// <summary>The IConfiguration section name for plugin settings.</summary>
    public const string PluginSectionName = "Plugins";

    /// <summary>Configuration key for the plugin probing directory path.</summary>
    public const string PluginDirectoryConfigRootKey = "PluginDirectory";

    /// <summary>Default plugin probing directory relative to the application base.</summary>
    public const string PluginDirectoryDefault = "Plugins";

    /// <summary>Configuration key for the maximum sub-directory probing depth.</summary>
    public const string PluginProbingDepthConfigRootKey = "PluginProbingDepth";

    /// <summary>Default probing depth (1 = immediate subdirectories only).</summary>
    public const string PluginProbingDepthDefault = "1";
    #endregion

    #region Exception messages
    public const string ExceptionPluginNotFound = "Plugin '{0}' was not found in the discovered plugins.";
    public const string ExceptionPluginAlreadyLoaded = "Plugin '{0}' is already loaded.";
    public const string ExceptionInvalidStateTransition = "Cannot transition plugin from {0} to {1}.";
    public const string ExceptionNoPluginLoaded = "No plugin is currently loaded for this family.";
    #endregion
  }
}
