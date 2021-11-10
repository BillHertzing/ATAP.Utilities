

namespace ATAP.Utilities.Testing {
  public static class StringConstants {
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

    #region string constants: EnvironmentVariablePrefixs
    public const string GenericTestEnvironmentVariablePrefixConfigRootKey = "GenericTest_";
    public const string GenericTestEnvironmentVariablePrefixDefault = "GenericTest_";
    public const string SpecificTestEnvironmentVariablePrefixConfigRootKey = "SpecificTest_";
    public const string SpecificTestEnvironmentVariablePrefixDefault = "SpecificTest_";
    #endregion

    // ToDo: replace with newest "best practices" that use IHostEnvironment (i.e., deprecate these)
    #region string constants: Environments
    public const string EnvironmentProductionTest = "ProductionTest"; // ToDo: Implement these tests
    public const string EnvironmentUnitTest = "UnitTest"; // Run Unit tests
    public const string EnvironmentConfigRootKey = "Environment";
    public const string EnvironmentDefault = EnvironmentUnitTest;
    #endregion

  }
}
