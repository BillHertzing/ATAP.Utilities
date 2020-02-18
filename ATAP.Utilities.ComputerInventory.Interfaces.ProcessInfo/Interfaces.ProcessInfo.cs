using System;

namespace ATAP.Utilities.ComputerInventory.Interfaces.ProcessInfo
{

  public interface IComputerProcess : IObservable<IComputerProcess>
  {
    bool Equals(IComputerProcess other);
    bool Equals(object obj);
    int GetHashCode();
    //IDisposable Subscribe(IObserver<IComputerProcess> observer);
  }


}
