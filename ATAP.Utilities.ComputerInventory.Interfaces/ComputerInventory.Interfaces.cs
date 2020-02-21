using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.ComputerInventory.Interfaces.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;

using System;

namespace ATAP.Utilities.ComputerInventory.Interfaces
{
  public interface IComputerInventory : IObservable<IComputerInventory>
  {
    IComputerHardware ComputerHardware { get; }
    IComputerProcesses ComputerProcesses { get; }
    IComputerSoftware ComputerSoftware { get; }

    new IDisposable Subscribe(IObserver<IComputerInventory> observer);
  }
}
