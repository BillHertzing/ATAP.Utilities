using System.Collections.Generic;

namespace ATAP.Services.GenerateCode {
  #region ATAP.Services.GenerateCode Default Configuration settings
  static public class DefaultConfiguration {
    // Create the minimal set of Configuration settings that the GenerateProgram  service needs to startup and run in production, but don't duplicate genericHost default settings
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      //{GenericHostStringConstants.SupressConsoleHostStartupMessagesConfigKey, GenericHostStringConstants.SupressConsoleHostStartupMessagesStringDefault},
    };
    #endregion
  }
}
