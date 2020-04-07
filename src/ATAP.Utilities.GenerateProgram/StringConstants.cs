
namespace ATAP.Utilities.HostedServices.GenerateProgram {
  public static class StringConstants {
    // ToDo: Localize the string constants

    #region Per-Service Configuration items
    #region GenerateProgram Configuration Items
    #region string constants: File Names 
    public const string SourcesRootPathConfigRootKey = "SourcesRootPath";
    public const string SourcesRootPathStringDefault = "./";
    public const string DestinationsRootPathConfigRootKey = "DestinationsRootPath";
    public const string DestinationsRootPathStringDefault = "./obj";
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase";
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\_1Console\\";
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
    #region string constants: App Settings File for this HostedService
    public const string GenerateProgramSettingsFileName = "GenerateProgramSettings";
    public const string GenerateProgramSettingsFileNameSuffix = "json";
    #endregion
    #endregion
    #endregion

  }
}

