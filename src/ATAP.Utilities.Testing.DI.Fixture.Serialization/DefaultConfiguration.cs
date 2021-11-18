using System.Collections.Generic;
namespace ATAP.Utilities.Testing.Fixture.Serialization {
  static public class DefaultConfiguration {
    // Create the minimal set of Configuration settings that a test runner needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      #region Serialization default settings
      {StringConstants.SerializerShimNameConfigRootKey, StringConstants.SerializerShimNameStringDefault},
      {StringConstants.SerializerShimNamespaceConfigRootKey, StringConstants.SerializerShimNamespaceStringDefault},
      #endregion
    };
  }
}
