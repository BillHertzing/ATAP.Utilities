using System;
using System.Collections.Generic;
using System.Text;

namespace FileSystemGraphToDBService {
  class StringConstants {

    #region Settings File Names
    public const string SettingsFileName = "FileSystemGraphToDBServiceSettings";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region File Names
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase"; //Get this from the current configuration root??
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\AService01\\";
    #endregion

    #region FileSystemGraphToDBService ConfigRootKeys
    public const string DBNameConfigRootKey = "DatabaseName";
    public const string DBNameStringDefault = "FileSystemGraph";
    public const string AsyncFileReadBlockSizeConfigRootKey = "AsyncFileReadBlockSize";
    public const string AsyncFileReadBlockSizeDefault = "4096";
    public const string EnableHashBoolConfigRootKey = "EnableHash";
    public const string EnableHashBoolConfigRootKeyDefault = "false";
    public const string EnableProgressBoolConfigRootKey = "EnableProgress";
    public const string EnableProgressBoolDefault = "false";
    public const string NodeFileRelativePathConfigRootKey = "NodeFileRelativePath";
    public const string NodeFileRelativePathDefault = "Node.txt";
    public const string EdgeFileRelativePathConfigRootKey = "EdgeFileRelativePath";
    public const string EdgeFileRelativePathDefault = "Edge.txt";
    public const string OrmLiteDialectProviderConfigRootKey = "ORMLiteDialectProvider";
    public const string OrmLiteDialectProviderStringDefault = "SqlServerOrmLiteDialectProvider";
    public const string OrmLiteDialectProviderGlobalConfigRootKey = "ORMLiteDialectProviderGlobal";
    public const string OrmLiteDialectProviderGlobalStringDefault = "SqlServerOrmLiteDialectProvider";

    #endregion
  }
}
