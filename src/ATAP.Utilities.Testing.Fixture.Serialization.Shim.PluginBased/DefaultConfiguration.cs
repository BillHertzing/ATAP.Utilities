using System.Collections.Generic;
namespace ATAP.Utilities.Testing.Fixture.Serialization.Shim.PluginBased {
  static public class DefaultConfiguration {
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
#region Serialization.Shim.PluginBased default settings
      {StringConstants.ShimName, StringConstants.ShimSystemTextJson},
#endregion
    };
  }
}
