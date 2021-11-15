

namespace ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson {
  public static class StringConstants {
    // ToDo: Localize the string constants
    // ToDo: constants for serializer options (this specific shim)
    // This identifies this specific shim
    // public const string ShimNameJsonSystemText = "ATAP.Utilities.Serializer.Shim.SystemTextJson.dll";
    // public const string ShimNameSpaceJsonSystemText = "ATAP.Utilities.Serializer.Shim.SystemTextJson";

    #region Settings File name (production)
    public const string SettingsFileName = "ATAP.Utilities.Testing.Fixture.Serialization";
    public const string SettingsFileNameSuffix = "json";
    #endregion
    #region ConfigurationRoot EnvironmentVariable Prefix
    public const string CustomEnvironmentVariablePrefix = "ATAPUtilitiesTestingFixtureSerialization";
    #endregion

  }
}
