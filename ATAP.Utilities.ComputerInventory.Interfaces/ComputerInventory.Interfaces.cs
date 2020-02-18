using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.ComputerInventory.Interfaces.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;
using ATAP.Utilities.ComputerInventory.Models.Hardware;
using ATAP.Utilities.ComputerInventory.Models.ProcessInfo;
using System;

namespace ATAP.Utilities.ComputerInventory.Interfaces
{
  public interface IComputerInventory : IObservable<IComputerInventory>
  {
    ComputerHardware ComputerHardware { get; }
    ComputerProcesses ComputerProcesses { get; }
    IComputerSoftware ComputerSoftware { get; }

    bool Equals(IComputerInventory other);
    bool Equals(object obj);
    int GetHashCode();

    //IDisposable Subscribe(IObserver<IComputerInventory> observer);
  }
}
