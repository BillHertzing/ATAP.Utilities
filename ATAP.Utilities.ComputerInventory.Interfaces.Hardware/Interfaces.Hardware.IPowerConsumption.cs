using System;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface IPowerConsumption //: IObservable<IPowerConsumption>
  {
    TimeSpan Period { get; set; }
    double Watts { get; set; }
    //IDisposable Subscribe(IObserver<IPowerConsumption> observer);
  }


}
