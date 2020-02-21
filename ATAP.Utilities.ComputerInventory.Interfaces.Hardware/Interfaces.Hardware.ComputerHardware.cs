using ATAP.Utilities.ComputerInventory.Enumerations;
using Itenso.TimePeriod;
using System;

namespace ATAP.Utilities.ComputerInventory.Interfaces.Hardware
{

  public interface IComputerHardware
  {
    ICPU[] CPUs { get; }
    bool IsCPUsEnabled { get; }
    bool IsFanControllerEnabled { get; }
    bool IsMainboardEnabled { get; }
    bool IsVideoCardsEnabled { get; }
    IMainBoard MainBoard { get; }
    TimeBlock Moment { get; set; }
    IVideoCard[] VideoCards { get; }
  }


}
