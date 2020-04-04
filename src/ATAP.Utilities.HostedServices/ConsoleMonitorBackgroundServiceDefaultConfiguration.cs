using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ATAP.Utilities.HostedServices {
  static public class GenerateProgramBackgroundServiceDefaultConfiguration {
    // Create the minimal set of Configuration settings that the Generic Host needs to startup and run in production
    public static Dictionary<string, string> Production =
    new Dictionary<string, string> {
      #region Services
      #region ConvertFileSystemToGraphAsyncTask
      {StringConstants.RootStringConfigRootKey, StringConstants.RootStringDefault},
      {StringConstants.AsyncFileReadBlockSizeConfigRootKey, StringConstants.AsyncFileReadBlockSizeDefault},
      {StringConstants.TemporaryDirectoryBaseConfigRootKey, StringConstants.TemporaryDirectoryBaseDefault},
      {StringConstants.EnableProgressBoolConfigRootKey, StringConstants.EnableProgressBoolDefault},
      {StringConstants.EnablePersistenceBoolConfigRootKey, StringConstants.EnablePersistenceBoolDefault},
      {StringConstants.WithPersistenceNodeFileRelativePathConfigRootKey, StringConstants.WithPersistenceNodeFileRelativePathDefault},
      {StringConstants.WithPersistenceEdgeFileRelativePathConfigRootKey, StringConstants.WithPersistenceEdgeFileRelativePathDefault},
      #endregion
      #endregion
    };
  }
}

