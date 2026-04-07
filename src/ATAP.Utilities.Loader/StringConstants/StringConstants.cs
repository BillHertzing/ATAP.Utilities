
namespace ATAP.Utilities.Loader {
  public static class StringConstants {
    // ToDo: Localize the string constants

   #region Loader library to use
    public const string LoaderAssemblyConfigRootKey = "LoaderAssembly";
    public const string LoaderAssemblyDefault = "ATAP.Utilities.Loader.Shim.McMaster";
    public const string LoaderNamespaceConfigRootKey = "LoaderNamespace";
    public const string LoaderNamespaceDefault = "ATAP.Utilities.Loader.Shim.McMaster";
    #endregion

    #region Plugin probing configuration
    public const string PluginDirectoryConfigRootKey = "PluginDirectory";
    public const string PluginDirectoryDefault = "Plugins";
    public const string PluginProbingDepthConfigRootKey = "PluginProbingDepth";
    public const string PluginProbingDepthDefault = "1";
    #endregion

    #region Exception messages
    public const string ExceptionAssemblyNotFound = "No assembly found matching glob pattern: {0}";
    public const string ExceptionMultipleAssembliesFound = "Expected exactly one assembly matching glob, found {0}: {1}";
    public const string ExceptionNoMatchingType = "No type matching predicate found in loaded assemblies.";
    public const string ExceptionMultipleMatchingTypes = "Expected exactly one matching type, found {0}.";
    #endregion

  }
}

