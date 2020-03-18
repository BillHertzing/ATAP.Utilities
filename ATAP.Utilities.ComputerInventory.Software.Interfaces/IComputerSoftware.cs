using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Software
{
  public interface IComputerSoftware
  {
    IEnumerable<IComputerSoftwareDriver> ComputerSoftwareDrivers { get; }
    IEnumerable<IComputerSoftwareProgram> ComputerSoftwarePrograms { get; }
    OperatingSystem OperatingSystem { get; }
  }
}
