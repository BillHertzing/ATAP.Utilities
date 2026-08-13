using ATAP.Utilities.DateTime.Interfaces;
using System;


namespace ATAP.Utilities.ComputerInventory.Hardware
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

    public ComputerHardware(ICPU[] cPUS, bool isCPUsEnabled, bool isFanControllerEnabled, bool isMainboardEnabled, bool isVideoCardsEnabled, IMainBoard mainBoard, UtcInstant moment, IVideoCard[] videoCards)
    {
      CPUS = cPUS ?? throw new ArgumentNullException(nameof(cPUS));
      IsCPUsEnabled = isCPUsEnabled;
      IsFanControllerEnabled = isFanControllerEnabled;
      IsMainboardEnabled = isMainboardEnabled;
      IsVideoCardsEnabled = isVideoCardsEnabled;
      MainBoard = mainBoard ?? throw new ArgumentNullException(nameof(mainBoard));
      Moment = moment;
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
    public UtcInstant Moment { get; }
    public IVideoCard[] VideoCards { get; }

    // ToDo: Add field and property for MainBoardMemory
    // ToDo: Add field and property for Disks
    // ToDo: Add field and property for PowerSupply
    // ToDo: Add field and property for USBPorts

  }
}
