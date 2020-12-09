
namespace ATAP.Console.Console01 {
  public static class AConsole01StringConstants {
    // ToDo: Localize the string constants

    #region Settings File Names
    public const string SettingsFileName = "AConsole01Settings";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region File Names
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase";
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\AConsole01\\";
    #endregion
    #region ConvertFileSystemToGraphConfigRootKeys
    public const string RootStringConfigRootKey = "RootString";
    public const string RootStringDefault = "E:\\";
    public const string AsyncFileReadBlockSizeConfigRootKey = "AsyncFileReadBlockSize";
    public const string AsyncFileReadBlockSizeDefault = "4096";
    public const string EnableHashBoolConfigRootKey = "EnableHash";
    public const string EnableHashBoolConfigRootKeyDefault = "false";
    public const string EnableProgressBoolConfigRootKey = "EnableProgress";
    public const string EnableProgressBoolDefault = "true";
    public const string EnablePersistenceBoolConfigRootKey = "EnablePersistence";
    public const string EnablePersistenceBoolDefault = "true";
    public const string EnablePickAndSaveBoolConfigRootKey = "EnablePickAndSave";
    public const string EnablePickAndSaveBoolDefault = "true";
    public const string WithPersistenceNodeFileRelativePathConfigRootKey = "WithPersistenceNodeFileRelativePath";
    public const string WithPersistenceNodeFileRelativePathDefault = "Node.txt";
    public const string WithPersistenceEdgeFileRelativePathConfigRootKey = "WithPersistenceEdgeFileRelativePath";
    public const string WithPersistenceEdgeFileRelativePathDefault = "Edge.txt";
    public const string WithPickAndSaveNodeFileRelativePathConfigRootKey = "WithPickAndSaveNodeFileRelativePath";
    public const string WithPickAndSaveNodeFileRelativePathDefault = "ArchiveFiles.txt";
    public const string DBConnectionStringConfigRootKey = "DBConnectionString";
    public const string DBConnectionStringDefault = @"Server=ncat016;Database=ATAPUtilities;Integrated Security=true";
    public const string OrmLiteDialectProviderConfigRootKey = "ORMLiteDialectProvider";
    public const string OrmLiteDialectProvider = "SqlServerOrmLiteDialectProvider";
    #endregion



  }
}

