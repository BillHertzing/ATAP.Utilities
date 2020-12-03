
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace FileSystemToObjectGraphService {
  static public class DefaultConfiguration {
    // Create the minimal set of Configuration settings that the AService01 app needs to startup and run in production, but don't duplicate genericHost default settings
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
        {StringConstants.OrmLiteDialectProviderConfigRootKey, StringConstants.OrmLiteDialectProviderStringDefault},
        //{StringConstants.OrmLiteDialectProviderGlobalConfigRootKey, StringConstants.OrmLiteDialectProviderGlobalStringDefault},

    };
  }
}
