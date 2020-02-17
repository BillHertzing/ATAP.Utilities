using ATAP.Utilities.ComputerInventory.Models;
using System;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{
  public interface ITempAndFan : IObservable<ITempAndFan>
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

}
