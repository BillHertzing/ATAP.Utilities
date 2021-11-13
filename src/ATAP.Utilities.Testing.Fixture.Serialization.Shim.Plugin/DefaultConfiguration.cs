using System.Collections;
namespace ATAP.Utilities.Testing.Fixture.Serialization.Shim.Plugin {
  static public class DefaultConfiguration {
    // Create the minimal set of Configuration settings that an application or test runner needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      {ATAP.Utilities.Testing.Fixture.SerializationStringConstants.SerializerShimNameConfigRootKey, StringConstants.ShimNamePlugin},
      {ATAP.Utilities.Testing.Fixture.SerializationStringConstants.SerializerShimNameSpaceConfigRootKey, StringConstants.ShimNameSpacePlugin}
    };
  }
}
