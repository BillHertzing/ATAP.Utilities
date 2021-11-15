

namespace ATAP.Utilities.Testing.Fixture.Serialization {
  public static class StringConstants {
    // ToDo: Localize the string constants

    #region ConfigKeys and default values for string-based Configkeys
    public const string SerializerShimNameConfigRootKey = "SerializerShimName";
    public const string SerializerShimNameStringDefault = "ATAP.Utilities.Serializer.Shim.SystemTextJson.dll";
    public const string SerializerShimNameSpaceConfigRootKey = "SerializerShimNameSpace";
    public const string SerializerShimNameSpaceStringDefault = "ATAP.Utilities.Serializer.Shim.SystemTextJson";
    #endregion

    #region Settings File name (production)
    public const string SettingsFileName = "ATAP.Utilities.Testing.Fixture.Serialization";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region ConfigurationRoot EnvironmentVariable Prefix
    public const string CustomEnvironmentVariablePrefix = "ATAPUtilitiesTestingFixtureSerialization";
    #endregion

  }
}
