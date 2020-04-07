
namespace ATAP.Utilities.HostedServices.ConsoleMonitor {
  public static class StringConstants {
    // ToDo: Localize the string constants
    #region Settings File Names
    public const string SettingsFileName = "ConsoleMonitorSettings";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region File Names
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase";
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\_1Console\\";
    #endregion
    #region ConvertFileSystemToGraph
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
    #endregion
  }
}

