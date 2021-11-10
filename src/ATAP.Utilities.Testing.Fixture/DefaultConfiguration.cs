using System.Collections.Generic;
namespace ATAP.Utilities.Testing.Fixture {
  static public class DefaultConfiguration {
    // Yhe Default configuration for a Test Fixture
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
    #region DIFixture settings
    // NinJect
      {StringConstants.DIShimNameConfigRootKey, StringConstants.DIShimNameStringDefault},
      {StringConstants.DIShimNameSpaceConfigRootKey, StringConstants.DIShimNameSpaceStringDefault},
    #endregion
    };
  }
}
