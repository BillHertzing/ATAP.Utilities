namespace ATAP.Console.PluginDemo;

public static class StringConstants
{
  public const string PluginDemoModeConfigRootKey = "PluginDemoMode";
  public const string PluginDemoModeDefault = "Static";

  public const string TestSecretName = "PluginDemo_TestSecret";
  public const string TestSecretFieldName = "Notes";

  public const string ConfigurationSecretName = "PluginDemo_ConfigurationSecret";
  public const string ConfigurationSecretFieldName = "Notes";
  public const string ConfigurationSecretConfigRootKey = "PluginDemo:ConfigurationSecret";

  public const string PluginDirectoryConfigRootKey = "PluginDirectory";
  public const string PluginDirectoryDefault = "Plugins";

  public const string SecretsPluginGlobPattern = "ATAP.Utilities.Secrets.Shim.Bitwarden.dll";

  public const string WelcomeMessage = "ATAP Plugin Architecture Demo";
  public const string ModeSelectionPrompt = "Select mode: [1] Static Reference, [2] Dynamic Plugin, [Q] Quit";
  public const string SecretRetrievedMessage = "Secret retrieved successfully: {0}****";
  public const string SecretNotFoundMessage = "Secret not found.";
  public const string SecretProviderNotFoundMessage = "Secret Provider unavailable.";
  public const string UnloadVerificationMessage = "Plugin ALC unloaded. GC collected: {0}";

  public const string ConfigurationSecretAvailableMessage =
    "Configuration secret '{SecretName}' read from Bitwarden and available in configuration at key '{ConfigKey}'. Value preview: {Preview}****";
  public const string ConfigurationSecretUnavailableMessage =
    "Configuration secret '{SecretName}' was NOT available from Bitwarden at configuration key '{ConfigKey}'";
}
