using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Software
{
  public static class DefaultConfiguration
  {
    public static IDictionary<string, IComputerSoftwareProgramSignil> Production = new Dictionary<string, IComputerSoftwareProgramSignil>() {
        { "Generic", new ComputerSoftwareProgramSignil("Generic", @".", ".", "0.0.0", true, true, true, ".", ".log", false, null, false, null)},
        { "PowerShell", new ComputerSoftwareProgramSignil("powershell", @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe", ".", "v5", true, true, true, ".", ".log", false, null, false, null)},
        { "EthDCRMiner",  new ComputerSoftwareProgramSignil("EthDCRMiner",@"C:\",".","v1",false,false,false,".",".log", false, null, false, null)}
      };
  }

}
