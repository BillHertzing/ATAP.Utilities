using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace GenerateProgram {
  static public class DefaultConfiguration {
    // Create the minimal set of Configuration settings that the Generic Host needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      #region GenerateProgram settings
      {StringConstants.TemporaryDirectoryBaseConfigRootKey, StringConstants.TemporaryDirectoryBaseDefault},
      #endregion
    };
  }
}
