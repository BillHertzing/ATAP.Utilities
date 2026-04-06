using System.Collections.Generic;

namespace ATAP.Console.PluginDemo;

public static class PluginDemoDefaultConfiguration
{
  public static Dictionary<string, string> Production => new()
  {
    { StringConstants.PluginDemoModeConfigRootKey, StringConstants.PluginDemoModeDefault },
    { StringConstants.PluginDirectoryConfigRootKey, StringConstants.PluginDirectoryDefault },
  };
}
