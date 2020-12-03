
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace AService01 {
  #region AService01 Default Configuration settings
  static public class AService01DefaultConfiguration {
    // Create the minimal set of Configuration settings that the AService01 app needs to startup and run in production, but don't duplicate genericHost default settings
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
        {AService01StringConstants.OrmLiteDialectProviderConfigRootKey, AService01StringConstants.OrmLiteDialectProviderStringDefault},
        {AService01StringConstants.OrmLiteDialectProviderGlobalConfigRootKey, AService01StringConstants.OrmLiteDialectProviderGlobalStringDefault},

    #endregion
    };
  }
}
