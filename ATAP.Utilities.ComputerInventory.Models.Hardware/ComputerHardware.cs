using System;
using Itenso.TimePeriod;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;

namespace ATAP.Utilities.ComputerInventory.Models.Hardware
{


  [Serializable]
#if NETFUL
  public class ComputerHardware : OpenHardwareMonitor.Hardware.Computer {
#else
  public class ComputerHardware : IComputerHardware
#endif
  {
    public ComputerHardware()
    {
    }

    public ComputerHardware(ICPU[] cPUS, bool isCPUsEnabled, bool isFanControllerEnabled, bool isMainboardEnabled, bool isVideoCardsEnabled, IMainBoard mainBoard, TimeBlock moment, IVideoCard[] videoCards)
    {
      CPUS = cPUS ?? throw new ArgumentNullException(nameof(cPUS));
      IsCPUsEnabled = isCPUsEnabled;
      IsFanControllerEnabled = isFanControllerEnabled;
      IsMainboardEnabled = isMainboardEnabled;
      IsVideoCardsEnabled = isVideoCardsEnabled;
      MainBoard = mainBoard ?? throw new ArgumentNullException(nameof(mainBoard));
      Moment = moment ?? throw new ArgumentNullException(nameof(moment));
      VideoCards = videoCards ?? throw new ArgumentNullException(nameof(videoCards));
    }
#if NETFUL
        readonly OpenHardwareMonitor.Hardware.Computer computer;
#endif

    public ICPU[] CPUS { get; }
    public bool IsCPUsEnabled { get; }
    public bool IsFanControllerEnabled { get; }
    public bool IsMainboardEnabled { get; }
    public bool IsVideoCardsEnabled { get; }
    public IMainBoard MainBoard { get; }
    public ITimeBlock Moment { get; }
    public IVideoCard[] VideoCards { get; }

    // ToDo: Add field and property for MainBoardMemory
    // ToDo: Add field and property for Disks
    // ToDo: Add field and property for PowerSupply
    // ToDo: Add field and property for USBPorts

  }
}
