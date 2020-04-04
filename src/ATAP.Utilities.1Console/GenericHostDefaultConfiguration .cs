using ATAP.Utilities.ComputerInventory.Software;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace ATAP.Utilities._1Console {
  static public class GenericHostDefaultConfiguration {
    // Create the minimal set of Configuration settings that the Generic Host needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
#region GenericHostDefault settings
      {StringConstants.EnvironmentConfigRootKey, StringConstants.EnvironmentProduction},
      {StringConstants.KindOfHostBuilderToBuildConfigRootKey,SupportedKindsOfHostBuilders.ConsoleHostBuilder.ToString()},
      {StringConstants.WebHostBuilderToBuildConfigRootKey, SupportedWebHostBuilders.KestrelAloneWebHostBuilder.ToString()},
      {StringConstants.GenericHostLifetimeConfigRootKey, SupportedGenericHostLifetimes.ConsoleLifetime.ToString()},
      {StringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownConfigKey, StringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownStringDefault},
      {StringConstants.SupressConsoleHostStartupMessagesConfigKey, StringConstants.SupressConsoleHostStartupMessagesStringDefault},
#endregion
    };
  }
}
