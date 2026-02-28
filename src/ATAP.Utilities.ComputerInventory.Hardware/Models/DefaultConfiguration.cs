using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Hardware
{
  static class DefaultConfiguration
  {
    public static Dictionary<string, string> Production => new Dictionary<string, string>() {
            { "ATAP.Utilities.ComputerInventory.Hardware.Placeholder", "placeholder" }
        };
  }
}
