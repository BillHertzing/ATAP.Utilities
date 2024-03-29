using ATAP.Utilities.ConcurrentObservableCollections;
using System;

namespace ATAP.Utilities.ComputerInventory.ProcessInfo
{
  public interface IComputerProcesses //: IObservable<IComputerProcesses>
  {
    ConcurrentObservableDictionary<int, IComputerProcess> ComputerProcessDictionary { get; }

    //new IDisposable Subscribe(IObserver<IComputerProcesses> observer);
  }
}
