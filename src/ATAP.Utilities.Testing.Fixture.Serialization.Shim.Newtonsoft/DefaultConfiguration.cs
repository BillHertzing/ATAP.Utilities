using System.Collections.Generic;
namespace ATAP.Utilities.Testing.Fixture.Serialization.Shim.Newtonsoft {
  static public class DefaultConfiguration {
    // Create the minimal set of Configuration settings that an application or test runner needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      {ATAP.Utilities.Testing.Fixture.Serialization.StringConstants.SerializerShimNameConfigRootKey, StringConstants.ShimNameNewtonsoft},
      {ATAP.Utilities.Testing.Fixture.Serialization.StringConstants.SerializerShimNameSpaceConfigRootKey, StringConstants.ShimNameSpaceNewtonsoft}
    };
  }
}
