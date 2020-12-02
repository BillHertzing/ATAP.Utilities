using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace ATAP.Utilities.HostedServices.ConsoleMonitor {
  static public class DefaultConfiguration {
    // Create the minimal set of Configuration settings that this service needs to startup and run in production
    internal static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      #region ConsoleMonitor settings
      #region GenerateProgram settings
      {StringConstants.TemporaryDirectoryBaseConfigRootKey, StringConstants.TemporaryDirectoryBaseDefault},
      {StringConstants.RootStringConfigRootKey, StringConstants.RootStringDefault},
      {StringConstants.AsyncFileReadBlockSizeConfigRootKey, StringConstants.AsyncFileReadBlockSizeDefault},
      #endregion
      #endregion
    };
  }
}
