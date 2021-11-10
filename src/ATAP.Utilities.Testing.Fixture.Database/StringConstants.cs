

namespace ATAP.Utilities.Testing.Fixture.Database {
  public static class StringConstants {
    // ToDo: Localize the string constants

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

    #region string constants for specific 3rd Party Shims
    // This identifies the specific Shims of which the database Fixture is aware and which it can use directly
    public const string EnvironmentMSSQLIntegrationTest = "MSSQLIntegrationTest";  // ToDo: Implement these tests
    public const string EnvironmentMySQLIntegrationTest = "MySQLIntegrationTest";  // ToDo: Implement these tests
    public const string EnvironmentSQLLiteIntegrationTest = "SQLiteIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentSSOrmLiteMSSQLIntegrationTest = "SSOrmLiteMSSQLIntegrationTest";
    public const string EnvironmentSSOrmLiteMySQLIntegrationTest = "SSOrmLiteMySQLIntegrationTest";
    public const string EnvironmentSSOrmLiteSQLLiteIntegrationTest = "SSOrmLiteSQLiteIntegrationTest";
    public const string EnvironmentDapperMSSQLIntegrationTest = "DapperMSSQLIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentDapperMySQLIntegrationTest = "DapperMySQLIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentDapperSQLiteIntegrationTest = "DapperSQLiteIntegrationTest"; // ToDo: Implement these tests
    public const string EnvironmentEFCoreIntegrationTest = "EFCoreIntegrationTest"; // ToDo: Implement these tests
    #endregion

    #region string constants for dynamically loaded database fixture shim(s)
    public const string PluginDatabaseFixtureShimIntegrationTest = "PluginDatabaseFixtureShimIntegrationTest"; // ToDo: Implement these tests
    #endregion
  }
}
