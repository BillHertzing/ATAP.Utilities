using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.ComputerInventory.Interfaces.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;

namespace ATAP.Utilities.ComputerInventory.Interfaces
{
  public interface IComputerInventory
  {
    IComputerHardware ComputerHardware { get; }
    IComputerProcesses ComputerProcesses { get; }
    IComputerSoftware ComputerSoftware { get; }

    bool Equals(IComputerInventory other);
    bool Equals(object obj);
    int GetHashCode();
  }
}
