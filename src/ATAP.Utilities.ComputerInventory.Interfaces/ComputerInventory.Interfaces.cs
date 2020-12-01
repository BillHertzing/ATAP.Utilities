using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.ComputerInventory.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Software;

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
