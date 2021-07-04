

namespace ATAP.Utilities.Testing {
  public static class TestingStringConstants {
    // ToDo: Localize the string constants

    #region string constants: File Names
    public const string GenericTestSettingsFileNameConfigRootKey = "GenericTestSettingsFileName";
    public const string GenericTestSettingsFileNameDefault = "GenericSettings";
    public const string GenericTestSettingsFileSuffixConfigRootKey = "GenericTestSettingsFileSuffix";
    public const string GenericTestSettingsFileSuffixDefault = ".json";
    public const string SpecificTestSettingsFileNameConfigRootKey = "SpecificTestSettingsFileName";
    public const string SpecificTestSettingsFileNameDefault = "Settings";
    public const string SpecificTestSettingsFileSuffixConfigRootKey = "SpecificTestSettingsFileSuffix";
    public const string SpecificTestSettingsFileSuffixDefault = ".json";
    #endregion

    #region string constants: Exception Messages
    public const string CannotReadEnvironmentVariablesSecurityExceptionMessage = "Test cannot read from the environment variables (Security)";
    #endregion

    #region ConfigKeys and default values for Databasename and Connection Strings
    public const string DatabaseConnectionStringConfigRootKey = "DatabaseConnectionString";
    public const string DatabaseConnectionStringDefault = "ConnectionStringMustBeDefinedElsewhere";
    public const string DatabaseNameConfigRootKey = "DatabaseName";
    public const string DatabaseNameDefault = "DefaultDatabaseName";
    #endregion

    #region ConfigKeys and default values for strings related to ServiceStack OrmLite Databases (only database technology agnostic/common)
    /// <summary>
    /// DatabaseProvider is only used by the ServiceStack OrmLite integration test
    /// </summary>
    public const string DatabaseProviderConfigRootKey = "DatabaseProvider";
    public const string DatabaseProviderDefault = "EmptyDefaultDatabaseProvider";

    #endregion

    #region string constants: EnvironmentVariablePrefixs
    public const string CustomEnvironmentVariablePrefixConfigRootKey = "GenericTest_";
    public const string CustomEnvironmentVariablePrefixDefault= "GenericTest_";
    #endregion

    // ToDo: replace with newest "best practices" that use IHostEnvironment (i.e., deprecate these)
    #region string constants: Environments
    public const string EnvironmentConfigRootKey = "Environment";
    public const string EnvironmentDefault = EnvironmentUnitTest;
    public const string EnvironmentProductionTest = "ProductionTest"; // ToDo: Implement these tests
    public const string EnvironmentUnitTest = "UnitTest"; // Run Unit tests
    public const string EnvironmentMSSQLIntegrationTest = "MSSQLIntegrationTest";
    public const string EnvironmentMySQLIntegrationTest = "MySQLIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentSQLLiteIntegrationTest = "SQLiteIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentSSOrmLiteSQLLiteIntegrationTest = "SSSOrmLiteSQLiteIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentSSOrmLiteMSSQLIntegrationTest = "SSOrmLiteMSSQLIntegrationTest";
    public const string EnvironmentSSOrmLiteMySQLIntegrationTest = "SSOrmLiteMySQLIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentDapperMSSQLIntegrationTest = "DapperMSSQLIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentDapperMySQLIntegrationTest = "DapperMySQLIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentDapperSQLiteIntegrationTest = "DapperSQLiteIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentEFCoreIntegrationTest = "EFCoreIntegrationTest"; // ToDo: Implement these tests
    #endregion


  }
}
