using System.Collections.Generic;
namespace ATAP.Utilities.Testing {
  static public class DefaultConfiguration {
    // Create the minimal set of Configuration settings that a test runner needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      #region GenericTestDefault settings for production
      {StringConstants.EnvironmentConfigRootKey, StringConstants.EnvironmentDefault},
      #endregion
    };
  }
}
