using ATAP.Utilities.ComputerInventory.Enumerations;
using System;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface ITempAndFan 
  {
    double FanPct { get; set; }
    double Temp { get; set; }
    //IDisposable Subscribe(IObserver<ITempAndFan> observer);
  }


  public interface IPowerConsumption : IObservable<IPowerConsumption>
  {
    TimeSpan Period { get; set; }
    double Watts { get; set; }
    //IDisposable Subscribe(IObserver<IPowerConsumption> observer);
  }

  public interface ICPU
  {
    CPUMaker CPUMaker { get; }

    bool Equals(ICPU other);
    bool Equals(object obj);
    int GetHashCode();
  }

}
