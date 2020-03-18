
using Itenso.TimePeriod;
using System;
using System.Collections.Generic;

namespace ATAP.Utilities.ComputerInventory.Hardware
{

  public interface IComputerHardware
  {
    ICPU[] CPUS { get; }
    bool IsCPUsEnabled { get; }
    bool IsFanControllerEnabled { get; }
    bool IsMainboardEnabled { get; }
    bool IsVideoCardsEnabled { get; }
    IMainBoard MainBoard { get; }
    ITimeBlock Moment { get; }
    IVideoCard[] VideoCards { get; }
  }
 
}
