
namespace ATAP.Console.Console03 {
  public static class GenericHostStringConstants {
    // ToDo: Localize the string constants

    #region string constants: File Names 
    public const string genericHostSettingsFileName = "genericHostSettings";
    public const string webHostSettingsFileName = "webHostSettings";
    public const string settingsTextFileSuffix = ".txt";
    public const string sSAppHostSettingsTextFileName = "SSAppHostSettings";
    public const string agentSettingsTextFileName = "Agent.BaseServicesSettings";
    public const string hostSettingsFileNameSuffix = ".json";
    //It would be nice if ServiceStack implemented the User Secrets pattern that ASP Core provides
    // Without that, the following string constant identifies an Environmental variable that can be populated with the name of a file
    public const string agentEnvironmentIndirectSettingsTextFileNameKey = "Agent.BaseServices.IndirectSettings.Path";
    #endregion

    #region string constants: Exception Messages
    public const string CannotConvertShutDownTimeoutInSecondsToDoubleExceptionMessage = "The value specified for a Shutdown Timeout ({0}) cannot be converted to a Double, please check the configuration settings";
    public const string cannotReadEnvironmentVariablesSecurityExceptionMessage = "Ace cannot read from the environment variables (Security)";
    public const string CouldNotCreateServiceStackVirtualFileMappingExceptionMessage = "Could not create ServiceStack Virtual File Mapping: ";
    public const string ConfigKeyGoogleMapsAPIKeyNotFoundExceptionMessage = "GoogleAPI Key does not exist in the AppSettings ";
    #endregion

    #region string constants: ConfigKeys and default values for string-based Configkeys
    public const string KindOfHostBuilderToBuildConfigRootKey = "KindOfHostBuilderToBuild";
    public const string KindOfHostBuilderToBuildStringDefault = "ConsoleHostBuilder";
    public const string WebHostBuilderToBuildConfigRootKey = "WebHostBuilderToBuild";
    public const string WebHostBuilderToBuildStringDefault = "KestrelAloneWebHostBuilder";
    public const string GenericHostLifetimeConfigRootKey = "GenericHostLifetime";
    public const string GenericHostLifetimeStringDefault = "ConsoleLifetime";
    public const string MaxTimeInSecondsToWaitForGenericHostShutdownConfigKey = "MaxTimeInSecondsToWaitForGenericHostShutdown";
    public const string MaxTimeInSecondsToWaitForGenericHostShutdownStringDefault = "10";
    public const string SupressConsoleHostStartupMessagesConfigKey = "SupressConsoleHostStartupMessages";
    public const string SupressConsoleHostStartupMessagesStringDefault = "true";
    public const string ConsoleAppConfigRootKey = "Console";
    #endregion

    #region Web server configuration information for the Blazor-based GUI
    public const string PhysicalRootPathConfigKey = "PhysicalRootPath";
    public const string PhysicalRootPathStringDefault = "./GUI/GUI";
    public const string URLSConfigRootKey = "urls";
    public const string configKeyAceAgentListeningOnString = "Ace.Agent.ListeningOn"; // Move to app assembly string constants
    #endregion

    #region Connection Strings and API configuration keys
    public const string configKeyRedisConnectionString = "RedisConnectionString";
    public const string configKeyMySqlConnectionString = "MySqlConnectionString";
    public const string configKeyGoogleMapsAPIKey = "GoogleMapsAPIKey";
    #endregion

    #region string constants: EnvironmentVariablePrefixs
    public const string CustomEnvironmentVariablePrefix = "Console03_";
    #endregion

    // ToDo: replace with newest "best practices" that use IHostEnvironment (i.e., deprecate these)
    #region string constants: Environments
    public const string EnvironmentProduction = "Production"; // Environments.Production
    public const string EnvironmentDevelopment = "Development";
    public const string EnvironmentDefault = EnvironmentProduction;
    public const string ENVIRONMENTConfigRootKey = "Environment";
    #endregion

    #region string constants: For running as a Windows Service (could/should be removed from the Console programs' string constants)
    public const string ServiceNameBase = "TBDNameYourService";
    public const string ServiceDisplayNameBase = "TBDNameYourService";
    public const string ServiceDescriptionBase = "TBDNameYourService";
    #endregion


  }
}

