
namespace ATAP.Services.HostedService.GenerateProgram {

  public static class StringConstants {
    // ToDo: Localize the string constants

    #region Settings File Names
    public const string SettingsFileName = "GenerateProgramHostedServiceSettings";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region File Names
    public const string TemporaryDirectoryBaseConfigRootKey = "TemporaryDirectoryBase";
    public const string TemporaryDirectoryBaseDefault = "D:\\Temp\\GenerateProgramHostedServiceSettingsFileDefault\\";
    #endregion
    #region ConvertFileSystemToGraphConfigRootKeys
    public const string ArtifactsDirectoryBaseConfigRootKey = "ArtifactsDirectoryBase";
    public const string ArtifactsDirectoryBaseDefault = ".\\Artifacts\\";
    public const string ArtifactsFileRelativePathConfigRootKey = "ArtifactsFileRelativePath";
    public const string ArtifactsFileRelativePathhDefault = ".\\";
    public const string EnableProgressBoolConfigRootKey = "EnableProgress";
    public const string EnableProgressBoolDefault = "true";
    public const string EnablePersistenceBoolConfigRootKey = "EnablePersistence";
    public const string EnablePersistenceBoolDefault = "true";
    public const string EnablePickAndSaveBoolConfigRootKey = "EnablePickAndSave";
    public const string EnablePickAndSaveBoolDefault = "true";
    public const string PersistenceMessageFileRelativePathConfigRootKey = "WithPersistenceMessageFileRelativePath";
    public const string PersistenceMessageFileRelativePathDefault = "GenerateProgramHostedServiceSettingsFileDefault.txt";
    public const string PickAndSaveMessageFileRelativePathConfigRootKey = "GenerateProgramHostedServiceSettingsFileDefaultWithPickAndSaveNodeFileRelativePath";
    public const string PickAndSaveMessageFileRelativePathDefault = "GenerateProgramHostedServiceSettingsFileDefaultWithPickAndSaveNodeFileRelativePath.txt";
    public const string DBConnectionStringConfigRootKey = "DBConnectionString";
    public const string DBConnectionStringDefault = @"Server=ncat016;Database=ATAPUtilities;Integrated Security=true";
    public const string OrmLiteDialectProviderConfigRootKey = "ORMLiteDialectProvider";
    public const string OrmLiteDialectProviderDefault = "SqlServerOrmLiteDialectProvider";
    #endregion



  }
}

