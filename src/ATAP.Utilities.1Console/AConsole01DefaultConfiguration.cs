using ATAP.Utilities.ComputerInventory.Software;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace ATAP.Utilities.AConsole01 {
  static public class AConsole01DefaultConfiguration {
    // Create the minimal set of Configuration settings that the AConsole01 app needs to startup and run in production, but don't duplicate genericHost default settings
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
#region AConsole01 Default settings
      {GenericHostStringConstants.SupressConsoleHostStartupMessagesConfigKey, GenericHostStringConstants.SupressConsoleHostStartupMessagesStringDefault},
#endregion
    };
  }
}
