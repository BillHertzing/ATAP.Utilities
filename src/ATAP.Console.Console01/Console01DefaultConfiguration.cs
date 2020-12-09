using System.Collections.Generic;

namespace ATAP.Console.Console01 {
  #region Console01 Default Configuration settings
  static public class Console01DefaultConfiguration {
    // Create the minimal set of Configuration settings that the Console01 app needs to startup and run in production, but don't duplicate genericHost default settings
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      {GenericHostStringConstants.SupressConsoleHostStartupMessagesConfigKey, GenericHostStringConstants.SupressConsoleHostStartupMessagesStringDefault},
    #endregion
    };
  }
}
