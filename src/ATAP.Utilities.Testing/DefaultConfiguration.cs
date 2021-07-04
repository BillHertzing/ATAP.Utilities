using System.Collections.Generic;
namespace ATAP.Utilities.Testing {
  static public class TestingDefaultConfiguration {
    // Create the minimal set of Configuration settings that a test runner needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
#region GenericTestDefault settings
      {TestingStringConstants.EnvironmentConfigRootKey, TestingStringConstants.EnvironmentDefault},
      // {GenericTestStringConstants.KindOfHostBuilderToBuildConfigRootKey,SupportedKindsOfHostBuilders.ConsoleHostBuilder.ToString()},
      // {GenericTestStringConstants.WebHostBuilderToBuildConfigRootKey, SupportedWebHostBuilders.KestrelAloneWebHostBuilder.ToString()},
      // {GenericTestStringConstants.GenericHostLifetimeConfigRootKey, SupportedGenericHostLifetimes.ConsoleLifetime.ToString()},
      // {GenericTestStringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownConfigKey, GenericTestStringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownStringDefault},
#endregion
    };
  }
}
