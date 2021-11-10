

namespace ATAP.Utilities.Testing.Fixture.Serialization {
  public static class StringConstants {
    // ToDo: Localize the string constants

    #region ConfigKeys and default values for string-based Configkeys
    public const string SerializerShimNameConfigRootKey = "SerializerShimName";
    public const string SerializerShimNameStringDefault = "ATAP.Utilities.Serializer.Shim.SystemTextJson.dll";

    public const string SerializerShimNameSpaceConfigRootKey = "SerializerShimNameSpace";
    public const string SerializerShimNameSpaceStringDefault = "ATAP.Utilities.Serializer.Shim.SystemTextJson";
    #endregion

    #region Serializer Shims
    // This identifies the specific Shims of which the SerializationFixture is aware and which it can use directly

    public const string JsonSystemtTextShimName = "ATAP.Utilities.Serializer.Shim.SystemTextJson.dll";
    public const string JsonSystemtTextShimNameSpace = "ATAP.Utilities.Serializer.Shim.SystemTextJson";
    public const string NewtonsoftShimName = "ATAP.Utilities.Serializer.Shim.Newtonsoft.dll";
    public const string NewtonsoftShimNameSpace = "ATAP.Utilities.Serializer.Shim.Newtonsoft";
    public const string ServiceStackShimName = "ATAP.Utilities.Serializer.Shim.ServiceStack.dll";
    public const string ServiceStackShimNameSpace = "ATAP.Utilities.Serializer.Shim.ServiceStack";
    #endregion

    #region string constants for Plugin loaded serialization fixture shim(s)
    public const string PluginShimName = "ATAP.Utilities.Serializer.Shim.Plugin.dll";
    #endregion

  }
}
