namespace ATAP.Utilities.Secrets;

public static class StringConstants
{
  public const string SecretsProviderNameConfigRootKey = "SecretsProviderAssembly";
  public const string SecretsProviderNameDefault = "ATAP.Utilities.Secrets.Shim.Bitwarden";
  public const string SecretsProviderNamespaceConfigRootKey = "SecretsProviderNamespace";
  public const string SecretsProviderNamespaceDefault = "ATAP.Utilities.Secrets.Shim.Bitwarden";
  public const string SecretsPluginDirectoryConfigRootKey = "SecretsPluginDirectory";
  public const string SecretsPluginDirectoryDefault = "Plugins";
  public const string SecretsPluginGlobPattern = "*Secrets.Shim.*.dll";
  public const string BitwardenSessionEnvVarDefault = "BW_SESSION";
  public const string BitwardenCliPathDefault = "bw";
  public const string BitwardenTimeoutDefault = "00:00:30";
  public const string ExceptionNoProvidersAvailable = "No secrets providers are available. Ensure at least one provider is configured.";
  public const string ExceptionBwSessionNotSet = "BW_SESSION environment variable is not set. Run Initialize-BitwardenSession (LoginScript.ps1) before accessing secrets.";
}
