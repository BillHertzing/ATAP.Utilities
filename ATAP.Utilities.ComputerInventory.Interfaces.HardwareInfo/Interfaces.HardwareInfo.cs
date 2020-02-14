using ATAP.Utilities.ComputerInventory.Models;
using System;

namespace ATAP.Utilities.ComputerInventory.Interface.HardwareInfo
{
  public interface ITempAndFan
  {
    double FanPct { get; set; }
    double Temp { get; set; }
    //IDisposable Subscribe(IObserver<TempAndFan> observer);

  }


  public interface IPowerConsumption : IObservable<PowerConsumption>
  {
    TimeSpan Period { get; set; }
    double Watts { get; set; }
  }
}
