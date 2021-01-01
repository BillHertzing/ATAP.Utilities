
namespace ATAP.Console.Console02 {
  public static class StringConstants {
    // ToDo: Localize the string constants

    #region Settings File Names
    public const string SettingsFileName = "Console02Settings";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region File Names
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase";
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\Console02\\";
    #endregion
    #region ToDo migrate to an ATAP Abstract class for Progress,and its stringconstants assembly
    public const string EnableProgressConfigRootKey = "EnableProgress";
    public const string EnableProgressDefault = "true";
    #endregion
    #region Serializer library to use
    public const string SerializerAssemblyConfigRootKey = "SerializerAssembly";
    public const string SerializerAssemblyDefault = "ATAP.Utilities.Serializer.Shim.ServiceStackJson";
    public const string SerializerNamespaceConfigRootKey = "SerializerNamespace";
    public const string SerializerNamespaceDefault = "ATAP.Utilities.Serializer";
    #endregion

    #region GenerateProgramConsole02MechanicalConfigRootKeys
    public const string RootStringConfigRootKey = "RootString";
    public const string RootStringDefault = "E:\\";
    public const string DBConnectionStringConfigRootKey = "DBConnectionString";
    public const string DBConnectionStringDefault = @"Server=tcp:ncat016;Database=GenerateProgram;Integrated Security=true";
    public const string OrmLiteDialectProviderConfigRootKey = "ORMLiteDialectProvider";
    public const string OrmLiteDialectProviderDefault = "SqlServerOrmLiteDialectProvider";
    #endregion



  }
}

