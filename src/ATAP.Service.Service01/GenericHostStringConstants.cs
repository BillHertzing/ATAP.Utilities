
namespace AService01 {
  public static class GenericHostStringConstants {
    // ToDo: Localize the string constants

    #region string constants: File Names
    public const string GenericHostSettingsFileName = "GenericHostSettings";
    public const string GenerichostSettingsFileNameSuffix = ".json";
    public const string WebHostSettingsFileName = "webHostSettings";
    public const string WebHostSettingsFileNameSuffix = ".json";
    public const string SSAppHostSettingsTextFileName = "SSAppHostSettings";
    public const string SSAppHostsettingsTextFileSuffix = ".txt";
    //It would be nice if ServiceStack implemented the User Secrets pattern that ASP Core provides
    // Without that, the following string constant identifies an Environmental variable that can be populated with the name of a file
    public const string EnvironmentIndirectSettingsTextFileNameKey = "GenericHost.IndirectSettings.Path";
    #endregion

    #region string constants: Exception Messages
    public const string CannotConvertShutDownTimeoutInSecondsToDoubleExceptionMessage = "The value specified for a Shutdown Timeout ({0}) cannot be converted to a Double, please check the configuration settings";
    public const string CannotReadEnvironmentVariablesSecurityExceptionMessage = "Cannot read the environment variables (Security)";
    public const string CouldNotCreateServiceStackVirtualFileMappingExceptionMessage = "Could not create ServiceStack Virtual File Mapping: ";
    public const string ConfigKeyGoogleMapsAPIKeyNotFoundExceptionMessage = "GoogleAPI Key does not exist in the ConfigurationRoot ";
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

    #region string constants: EnvironmentVariablePrefixs
    public const string CustomEnvironmentVariablePrefix = "AService01GenericHost_";
    #endregion

    // ToDo: replace with newest "best practices" that use IHostEnvironment
    #region string constants: Environments prior to and part of the GenericHost creation . Very hard to localize/standardize in the short period before the environment is determined.
    public const string ENVIRONMENTConfigRootKey = "Environment";
    public const string EnvironmentProduction = "Production"; // Environments.Production
    public const string EnvironmentDevelopment = "Development";
    public const string EnvironmentStringDefault = EnvironmentProduction;
    #endregion

    #region string constants: For running as a Windows Service
    public const string ServiceNameBase = "TBDNameYourService";
    public const string ServiceDisplayNameBase = "TBDNameYourService";
    public const string ServiceDescriptionBase = "TBDNameYourService";
    #endregion

    #region Constants that should go into webhost string constants
    public const string PhysicalRootPathConfigRootKey = "PhysicalRootPath";
    public const string PhysicalRootPathStringDefault = "./GUI/GUI";
    public const string URLSConfigRootKey = "urls";
    public const string ListeningOnStringConfigRootKey = "AService01.ListeningOn";

    #endregion

    #region Constants that should go into ServiceStack as a service hosted by the webHost

    #endregion
    #region Constants for GoogleMapsService // Still Todo
    public const string GoogleMapsAPIKeyConfigRootKey = "GoogleMapsAPIKey";
    #endregion

  }
}

