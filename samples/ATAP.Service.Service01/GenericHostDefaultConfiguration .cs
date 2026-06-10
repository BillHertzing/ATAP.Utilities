using ATAP.Utilities.ComputerInventory.Software;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace AService01 {
  static public class GenericHostDefaultConfiguration {
    // Create the minimal set of Configuration settings that the Generic Host needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
#region GenericHostDefault settings
      {GenericHostStringConstants.ENVIRONMENTConfigRootKey, GenericHostStringConstants.EnvironmentProduction},
      {GenericHostStringConstants.KindOfHostBuilderToBuildConfigRootKey,SupportedKindsOfHostBuilders.ConsoleHostBuilder.ToString()},
      {GenericHostStringConstants.WebHostBuilderToBuildConfigRootKey, SupportedWebHostBuilders.KestrelAloneWebHostBuilder.ToString()},
      {GenericHostStringConstants.GenericHostLifetimeConfigRootKey, SupportedGenericHostLifetimes.ConsoleLifetime.ToString()},
      {GenericHostStringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownConfigKey, GenericHostStringConstants.MaxTimeInSecondsToWaitForGenericHostShutdownStringDefault},
      {GenericHostStringConstants.SupressConsoleHostStartupMessagesConfigKey, GenericHostStringConstants.SupressConsoleHostStartupMessagesStringDefault},

#endregion
    };
  }
}
