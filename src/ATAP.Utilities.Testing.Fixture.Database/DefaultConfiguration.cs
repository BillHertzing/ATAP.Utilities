using System.Collections.Generic;
namespace ATAP.Utilities.Testing.Fixture.Database {
  static public class DefaultConfiguration {
    // Create the minimal set of Configuration settings that a test runner needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
#region GenericTestDefault settings
      {StringConstants.ShimName, StringConstants.ShimMSSQL},
      // {GenericTestStringConstants.KindOfHostBuilderToBuildConfigRootKey,SupportedKindsOfHostBuilders.ConsoleHostBuilder.ToString()},
      // {GenericTestStringConstants.WebHostBuilderToBuildConfigRootKey, SupportedWebHostBuilders.KestrelAloneWebHostBuilder.ToString()},
      // {GenericTestStringConstants.GenericHostLifetimeConfigRootKey, SupportedGenericHostLifetimes.ConsoleLifetime.ToString()},
      // {GenericTestStringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownConfigKey, GenericTestStringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownStringDefault},
#endregion
    };
  }
}
