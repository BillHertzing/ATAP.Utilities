
using ATAP.Utilities.DateTime.Interfaces;
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
    UtcInstant Moment { get; }
    IVideoCard[] VideoCards { get; }
  }
 
}
