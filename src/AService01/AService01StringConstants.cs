
namespace AService01 {
  public static class AService01StringConstants {
    // ToDo: What is a good pattern to follow, to localize the settings and configuration files

    #region Settings File Names
    public const string SettingsFileName = "AService01Settings";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region File Names
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase"; //Get this from the current configuration root??
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\AService01\\";
    #endregion
    #region SS App constants
    #region DatabaseConfigRootKeys
    public const string RedisConnectionStringConfigRootKey = "RedisConnectionString";
    public const string RedisConnectionStringDefault = "ThereIsNoDefault";
    public const string MySQLStringConfigRootKey = "MySQLConnectionString";
    public const string MySQLConnectionStringDefault = "ThereIsNoDefault";
    public const string SQLServerConnectionStringConfigRootKey = "SQLServerConnectionString";
    public const string SQLServerConnectionStringDefault = "ThereIsNoDefault";
    public const string OrmLiteDialectProviderConfigRootKey = "ORMLiteDialectProvider";
    public const string OrmLiteDialectProviderStringDefault = "SqlServerOrmLiteDialectProvider";
    public const string OrmLiteDialectProviderGlobalConfigRootKey = "ORMLiteDialectProviderGlobal";
    public const string OrmLiteDialectProviderGlobalStringDefault = "SqlServerOrmLiteDialectProvider";

    public const string DBConnectionStringConfigRootKey = "DBConnectionString";
    public const string DBConnectionStringDefault = "ConnectionStringsAreDefinedInEnvironmentVariablesAndUserSecrets"; //"@"Server=ncat016;Database=ATAPUtilities;Integrated Security=true";
    #endregion
    #endregion

    #region GenerateProgram ConfigRootKeys
    #endregion
  }

}

