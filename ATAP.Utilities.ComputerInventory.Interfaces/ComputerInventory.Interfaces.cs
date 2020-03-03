using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.ComputerInventory.Interfaces.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;

using System;

namespace ATAP.Utilities.ComputerInventory.Interfaces
{
  public interface IComputerInventory 
  {
    IComputerHardware ComputerHardware { get; }
    IComputerProcesses ComputerProcesses { get; }
    IComputerSoftware ComputerSoftware { get; }
  }
}
