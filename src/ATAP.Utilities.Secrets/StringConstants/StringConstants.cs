namespace ATAP.Utilities.Secrets;

public static class StringConstants
{
  public const string SecretsProviderNameConfigRootKey = "SecretsProviderAssembly";
  public const string SecretsProviderNamespaceConfigRootKey = "SecretsProviderNamespace";
  public const string SecretsPluginDirectoryConfigRootKey = "SecretsPluginDirectory";
  public const string SecretsPluginDirectoryDefault = "Plugins";
  public const string SecretsPluginGlobPattern = "*Secrets.*.dll";
  public const string ExceptionNoProvidersAvailable = "No secrets providers are available. Ensure at least one provider is configured.";
}