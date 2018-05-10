using System;
using ATAP.Utilities.ComputerInventory.Models;
using Itenso.TimePeriod;

namespace ATAP.Utilities.ComputerInventory {
    [Serializable]
#if NETFUL
  public class ComputerHardware : OpenHardwareMonitor.Hardware.Computer {
#else
    public class ComputerHardware
#endif
  {
#if NETFUL
        readonly OpenHardwareMonitor.Hardware.Computer computer;
#endif
    readonly CPU[] cPUs;
    readonly bool isCPUsEnabled;
    readonly bool isFanControllerEnabled;
    readonly bool isMainboardEnabled;
    readonly bool isVideoCardsEnabled;
    readonly MainBoard mainBoard;
    TimeBlock moment;
    readonly VideoCard[] videoCards;

    public ComputerHardware(CPU[] cPUs, MainBoard mainBoard, VideoCard[] videoCards) {
        isMainboardEnabled = true;
      isCPUsEnabled = true;
      isVideoCardsEnabled = true;
      isFanControllerEnabled = true;
      this.cPUs = cPUs;
      this.mainBoard = mainBoard;
      this.videoCards = videoCards;
      this.moment = new TimeBlock(DateTime.UtcNow, true);
#if NETFUL
      this.computer = new Computer
      {
        MainboardEnabled = isMainboardEnabled,
        CPUEnabled = isCPUsEnabled,
        FanControllerEnabled = isFanControllerEnabled,
        GPUEnabled = isVideoCardsEnabled
      };
      // ToDo: Get teh HardwareMonitorLib to work, right now, it throws an exception it can't find system.management dll
      //computer.Open();
#endif
    }

#if NETFULL
    //public Computer Computer => computer;
#endif

    // ToDo: Add field and property for MainBoardMemory
    // ToDo: Add field and property for Disks
    // ToDo: Add field and property for PowerSupply
    // ToDo: Add field and property for USBPorts

    public CPU[] CPUs => cPUs;

    public bool IsCPUsEnabled => isCPUsEnabled;

    public bool IsFanControllerEnabled => isFanControllerEnabled;

    public bool IsMainboardEnabled => isMainboardEnabled;

    public bool IsVideoCardsEnabled => isVideoCardsEnabled;

    public MainBoard MainBoard => mainBoard;

    public TimeBlock Moment {
        get => moment; set => moment = value;
    }

    public VideoCard[] VideoCards => videoCards;

    public ComputerHardware(CPU[] cPUs, MainBoard mainBoard, VideoCard[] videoCards, TimeBlock moment) {
        isMainboardEnabled = true;
      isCPUsEnabled = true;
      isVideoCardsEnabled = true;
      isFanControllerEnabled = true;
      this.cPUs = cPUs;
      this.mainBoard = mainBoard;
      this.videoCards = videoCards;
      this.moment = moment;
#if NETFUL
      this.computer = new Computer { MainboardEnabled = isMainboardEnabled
          , CPUEnabled = isCPUsEnabled
          , FanControllerEnabled = isFanControllerEnabled
          , GPUEnabled = isVideoCardsEnabled
      };
      // ToDo: Get teh HardwareMonitorLib to work, right now, it throws an exception it can't find system.management dll
      //computer.Open();
#endif
    }
  }
}
