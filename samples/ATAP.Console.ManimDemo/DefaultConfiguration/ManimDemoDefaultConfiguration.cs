using System.Collections.Generic;

namespace ATAP.Console.ManimDemo;

public static class ManimDemoDefaultConfiguration
{
  public static Dictionary<string, string?> Production => new()
  {
    { StringConstants.ScenesRootPathConfigRootKey, StringConstants.ScenesRootPathDefault },
    { StringConstants.VenvPathConfigRootKey, StringConstants.VenvPathDefault },
    { StringConstants.DefaultQualityConfigRootKey, StringConstants.DefaultQualityDefault },
  };
}
