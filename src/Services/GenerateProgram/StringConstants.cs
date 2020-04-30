
namespace GenerateProgram { 
  public static class StringConstants {
    // ToDo: Localize the string constants
    #region Settings File Names
    public const string SettingsFileName = "GenerateProgramSettings";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region File Names
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase";
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\GenerateProgram\\";
    #endregion
    #region Per-Service Configuration items
    #region GenerateProgram Configuration Items
    #region string constants: File Names 
    public const string SourcesRootPathConfigRootKey = "SourcesRootPath";
    public const string SourcesRootPathStringDefault = "./";
    public const string DestinationsRootPathConfigRootKey = "DestinationsRootPath";
    public const string DestinationsRootPathStringDefault = "./obj";
    #endregion
    #region string constants: Exception Messages
    #endregion

    #region Database ConnectionKeys
    public const string RedisConnectionStringConfigRootKey = "RedisConnectionString";
    public const string MySqlConnectionStringConfigRootKey = "MySqlConnectionString";
    #endregion

    #region string constants: EnvironmentVariablePrefixs
    public const string CustomEnvironmentVariablePrefix = "GenerateProgram_";
    #endregion
 
    #endregion
    #endregion

  }
}

