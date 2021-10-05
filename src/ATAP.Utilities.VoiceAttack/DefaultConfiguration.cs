
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.VoiceAttack
{
  public static class DefaultConfiguration
  {
    public static Dictionary<string, string> Production = new Dictionary<string, string>() {
        { StringConstants.ProfileConfigRootKey, StringConstants.ProfileNameDefault},
        { StringConstants.TemporaryDirectoryBaseConfigRootKey, StringConstants.TemporaryDirectoryBaseDefault},
        { StringConstants.PluginPathBaseConfigRootKey, StringConstants.PluginPathBaseDefault},
        { StringConstants.EnableProgressConfigRootKey, StringConstants.EnableProgressDefault},
        { StringConstants.PersistencePathBaseDefault, StringConstants.PersistencePathBaseConfigRootKey},
      };
  }

  public static class DefaultConfigurationAOE
  {
    public static Dictionary<string, string> Production = new Dictionary<string, string>() {
        { StringConstants.ProfileConfigRootKey, StringConstants.ProfileNameDefault},
        { StringConstants.TemporaryDirectoryBaseConfigRootKey, StringConstants.TemporaryDirectoryBaseDefault},
        { StringConstants.PluginPathBaseConfigRootKey, StringConstants.PluginPathBaseDefault},
        { StringConstants.EnableProgressConfigRootKey, StringConstants.EnableProgressDefault},
        { StringConstants.PersistencePathBaseDefault, StringConstants.PersistencePathBaseConfigRootKey},
      };
  }

}
