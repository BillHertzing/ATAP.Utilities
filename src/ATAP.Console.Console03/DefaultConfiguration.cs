using System.Collections.Generic;

namespace ATAP.Console.Console03 {
  #region Console03 Default Configuration settings
  static public class Console03DefaultConfiguration {
    // Create the minimal set of Configuration settings that the Console03 app needs to startup and run in production, but don't duplicate genericHost default settings
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      {GenericHostStringConstants.SupressConsoleHostStartupMessagesConfigKey, GenericHostStringConstants.SupressConsoleHostStartupMessagesStringDefault},
    #endregion
    };
  }
}
