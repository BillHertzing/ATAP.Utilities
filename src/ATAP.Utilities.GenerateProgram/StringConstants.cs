
namespace ATAP.Utilities.GenerateProgram {
  public static class StringConstants {
    // ToDo: Localize the string constants

    #region Per-Service Configuration items
    #region GenerateProgram Configuration Items
    #region string constants: File Names 
    public const string PhysicalRootPathConfigRootKey = "PhysicalRootPath";
    public const string PhysicalRootPathStringDefault = "./";
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase";
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\_1Console\\";
    #endregion
    #region string constants: Exception Messages
    #endregion

    #region Database ConnectionKeys
    public const string KeyRedisConnectionStringConfigRootKey = "RedisConnectionString";
    public const string KeyMySqlConnectionStringConfigRootKey = "MySqlConnectionString";
    #endregion

    #region string constants: EnvironmentVariablePrefixs
    public const string CustomEnvironmentVariablePrefix = "GenerateProgram_";
    #endregion
    #region GenerateProgram
    public const string GenerateProgramOutputRelativePathConfigRootKey = "GenerateProgramOutputRelativePath";
    public const string GenerateProgramOutputRelativePathDefault = "./obj";

    #endregion
    #endregion
    #endregion

  }
}

