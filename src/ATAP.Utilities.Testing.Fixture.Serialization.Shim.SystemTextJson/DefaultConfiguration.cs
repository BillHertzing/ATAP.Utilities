using System.Collections.Generic;
namespace ATAP.Utilities.Testing.Fixture.Serialization.Shim.SystemTextJson {
  static public class DefaultConfiguration {
    // Create the minimal set of Configuration settings that an application or test runner needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      // ToDo: Localize the string constants
      // ToDo: constants for serializer options (this specific shim)
      // {ATAP.Utilities.Testing.Fixture.SerializationStringConstants.SerializerShimNameConfigRootKey, StringConstants.ShimNameSystemTextJson},
      // {ATAP.Utilities.Testing.Fixture.SerializationStringConstants.SerializerShimNameSpaceConfigRootKey, StringConstants.ShimNameSpaceSystemTextJson}
    };
  }
}
