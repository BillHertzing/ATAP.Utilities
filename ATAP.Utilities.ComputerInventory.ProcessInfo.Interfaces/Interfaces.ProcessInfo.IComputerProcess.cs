using ATAP.Utilities.ComputerInventory.Software;
using System;
using Medallion.Shell;

namespace ATAP.Utilities.ComputerInventory.ProcessInfo
{

  public interface IComputerProcess //: IObservable<IComputerProcess>
  {
    object[] Arguments { get; set; }
    Command Command { get; set; }
    IComputerSoftwareProgram ComputerSoftwareProgram { get; }
    //new IDisposable Subscribe(IObserver<IComputerProcess> observer);
  }

}
