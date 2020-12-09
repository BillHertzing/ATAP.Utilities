using System;
using System.Collections.Generic;
using System.Text;

namespace FileSystemToObjectGraphService {
  static class StringConstants {


    #region Settings File Names
    public const string SettingsFileName = "FileSystemToObjectGraphServiceSettings";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region File Names
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase";
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\Console01\\FileSystemToObjectGraphService\\";
    #endregion
    #region FileSystemToObjectGraphService ConfigRootKeys and default values
    public const string RootStringConfigRootKey = "RootString";
    public const string RootStringDefault = "E:\\";
    public const string AsyncFileReadBlockSizeConfigRootKey = "AsyncFileReadBlockSize";
    public const string AsyncFileReadBlockSizeDefault = "4096";
    public const string EnableHashBoolConfigRootKey = "EnableHash";
    public const string EnableHashBoolDefault = "false";
    public const string EnableProgressBoolConfigRootKey = "EnableProgress";
    public const string EnableProgressBoolDefault = "true";
    public const string EnablePersistenceBoolConfigRootKey = "EnablePersistence";
    public const string EnablePersistenceBoolDefault = "true";
    public const string EnablePickAndSaveBoolConfigRootKey = "EnablePickAndSave";
    public const string EnablePickAndSaveBoolDefault = "true";
    public const string PersistenceNodeFileRelativePathConfigRootKey = "PersistenceNodeFileRelativePath";
    public const string PersistenceNodeFileRelativePathDefault = "Node.txt";
    public const string PersistenceEdgeFileRelativePathConfigRootKey = "PersistenceEdgeFileRelativePath";
    public const string PersistenceEdgeFileRelativePathDefault = "Edge.txt";
    public const string PickAndSaveNodeFileRelativePathConfigRootKey = "PickAndSaveNodeFileRelativePath";
    public const string PickAndSaveNodeFileRelativePathDefault = "ArchiveFiles.txt";
    public const string DBConnectionStringConfigRootKey = "DBConnectionString";
    public const string DBConnectionStringDefault = @"Server=ncat016;Database=ATAPUtilities;Integrated Security=true";
    public const string OrmLiteDialectProviderConfigRootKey = "ORMLiteDialectProvider";
    public const string OrmLiteDialectProviderStringDefault = "SqlServerOrmLiteDialectProvider";
    #endregion

  }
}
