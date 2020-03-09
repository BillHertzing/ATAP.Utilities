using System;
using Itenso.TimePeriod;
using System.Collections.Generic;
using System.Runtime.Serialization;
using System.ComponentModel;
using System.Globalization;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using ATAP.Utilities.ComputerInventory.Models.Hardware;
using UnitsNet;
using UnitsNet.Units;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using ATAP.Utilities.ComputerInventory.Enumerations.Hardware;

namespace ATAP.Utilities.ComputerInventory.Models.Hardware
{

  /*
  public class DiskDrivePartitionDriveLetterIdentifier {
      public DiskDrivePartitionDriveLetterIdentifier() : { }
      public DiskDrivePartitionDriveLetterIdentifier(IDictionary<Guid, IDictionary<Guid, string>> diskDrivePartitionInfoGuidsDriveLetterStrings) { DiskDrivePartitionInfoGuidsDriveLetterStrings=diskDrivePartitionInfoGuidsDriveLetterStrings; }
      public IDictionary<Guid, IDictionary<Guid, string>> DiskDrivePartitionInfoGuidsDriveLetterStrings { get; set; }
  }


  [Serializable]
  public class MainBoard : ISerializable, IMainBoard, IEquatable<MainBoard>
  {

    public MainBoard() : this(MainBoardMaker.Generic, CPUSocket.Generic) { }

    public MainBoard(MainBoardMaker maker, CPUSocket cPUSocket)
    {
      Maker = maker;
      CPUSocket = cPUSocket;
    }

    MainBoard(SerializationInfo info, StreamingContext ctxt)
    {
      ///ToDo: figure out why the static extension method found in utilities.Enumerations doesn't work
      //this.maker = MainBoardMaker.ToEnum<MainBoardMaker>(info.GetString("Maker"));
      Maker = (MainBoardMaker)Enum.Parse(typeof(MainBoardMaker), info.GetString("Maker"), true);
      CPUSocket = (CPUSocket)Enum.Parse(typeof(CPUSocket), info.GetString("CPUSocket"), true);
    }

    void ISerializable.GetObjectData(SerializationInfo info, StreamingContext context)
    {
      info.AddValue("Maker", Maker.ToString());
      info.AddValue("CPUSocket", CPUSocket.ToString());
    }

    public override bool Equals(object obj)
    {
      return Equals(obj as MainBoard);
    }

    public bool Equals(MainBoard other)
    {
      return other != null &&
             Maker == other.Maker &&
             CPUSocket == other.CPUSocket;
    }

    public override int GetHashCode()
    {
      var hashCode = 1129616743;
      hashCode = hashCode * -1521134295 + Maker.GetHashCode();
      hashCode = hashCode * -1521134295 + CPUSocket.GetHashCode();
      return hashCode;
    }

    public MainBoardMaker Maker { get; }

    public CPUSocket CPUSocket { get;  }

    public static bool operator ==(MainBoard left, MainBoard right)
    {
      return EqualityComparer<MainBoard>.Default.Equals(left, right);
    }

    public static bool operator !=(MainBoard left, MainBoard right)
    {
      return !(left == right);
    }
  }

  [Serializable]
  public class CPU : IEquatable<CPU>, ICPU
  {
    public CPU()
    {
    }

    public CPU(CPUMaker cPUMaker)
    {
      CPUMaker = cPUMaker;
    }

    public CPUMaker CPUMaker { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as CPU);
    }

    public bool Equals(CPU other)
    {
      return other != null &&
             CPUMaker == other.CPUMaker;
    }

    public override int GetHashCode()
    {
      return 1556992827 + CPUMaker.GetHashCode();
    }

    public static bool operator ==(CPU left, CPU right)
    {
      return EqualityComparer<CPU>.Default.Equals(left, right);
    }

    public static bool operator !=(CPU left, CPU right)
    {
      return !(left == right);
    }
  }

  */
  [Serializable]
  public class VideoCardSensorData : IVideoCardSensorData, IEquatable<VideoCardSensorData>
  {
    public VideoCardSensorData()
    {
    }

    public VideoCardSensorData(UnitsNet.Units.FrequencyUnit coreClock, UnitsNet.Units.ElectricPotentialDcUnit coreVoltage, double fanRPM, UnitsNet.Units.FrequencyUnit memClock, double powerConsumption, double powerLimit, UnitsNet.Units.TemperatureUnit temp)
    {
      CoreClock = coreClock;
      CoreVoltage = coreVoltage;
      FanRPM = fanRPM;
      MemClock = memClock;
      PowerConsumption = powerConsumption;
      PowerLimit = powerLimit;
      Temp = temp;
    }

    public UnitsNet.Units.FrequencyUnit CoreClock { get; }
    public UnitsNet.Units.ElectricPotentialDcUnit CoreVoltage { get; }
    public double FanRPM { get; }
    public UnitsNet.Units.FrequencyUnit MemClock { get; }
    public double PowerConsumption { get; }
    public double PowerLimit { get; }
    public UnitsNet.Units.TemperatureUnit Temp { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as VideoCardSensorData);
    }

    public bool Equals(VideoCardSensorData other)
    {
      return other != null &&
             CoreClock == other.CoreClock &&
             CoreVoltage == other.CoreVoltage &&
             FanRPM == other.FanRPM &&
             MemClock == other.MemClock &&
             PowerConsumption == other.PowerConsumption &&
             PowerLimit == other.PowerLimit &&
             Temp == other.Temp;
    }

    public override int GetHashCode()
    {
      var hashCode = -485759360;
      hashCode = hashCode * -1521134295 + CoreClock.GetHashCode();
      hashCode = hashCode * -1521134295 + CoreVoltage.GetHashCode();
      hashCode = hashCode * -1521134295 + FanRPM.GetHashCode();
      hashCode = hashCode * -1521134295 + MemClock.GetHashCode();
      hashCode = hashCode * -1521134295 + PowerConsumption.GetHashCode();
      hashCode = hashCode * -1521134295 + PowerLimit.GetHashCode();
      hashCode = hashCode * -1521134295 + Temp.GetHashCode();
      return hashCode;
    }

    public static bool operator ==(VideoCardSensorData left, VideoCardSensorData right)
    {
      return EqualityComparer<VideoCardSensorData>.Default.Equals(left, right);
    }

    public static bool operator !=(VideoCardSensorData left, VideoCardSensorData right)
    {
      return !(left == right);
    }
  }



  [Serializable]
  public class VideoCard : IVideoCard, IEquatable<VideoCard>
  {
    public VideoCard()
    {
    }

    public VideoCard(string bIOSVersion, Frequency coreClock, ElectricPotentialDc coreVoltage, string deviceID, bool isStrapped, Frequency memClock, IPowerConsumption powerConsumption, IVideoCardSignil videoCardSignil)
    {
      BIOSVersion = bIOSVersion ?? throw new ArgumentNullException(nameof(bIOSVersion));
      CoreClock = coreClock;
      CoreVoltage = coreVoltage;
      DeviceID = deviceID ?? throw new ArgumentNullException(nameof(deviceID));
      IsStrapped = isStrapped;
      MemClock = memClock;
      PowerConsumption = powerConsumption;
      VideoCardSignil = videoCardSignil ?? throw new ArgumentNullException(nameof(videoCardSignil));
    }

    public string BIOSVersion { get; }
    public UnitsNet.Frequency CoreClock { get; }
    public UnitsNet.ElectricPotentialDc CoreVoltage { get; }
    public string DeviceID { get; }
    public bool IsStrapped { get; }
    public UnitsNet.Frequency MemClock { get; }
    public IPowerConsumption PowerConsumption { get; }
    public IVideoCardSignil VideoCardSignil { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as VideoCard);
    }

    public bool Equals(VideoCard other)
    {
      return other != null &&
             BIOSVersion == other.BIOSVersion &&
             CoreClock.Equals(other.CoreClock) &&
             CoreVoltage == other.CoreVoltage &&
             DeviceID == other.DeviceID &&
             IsStrapped == other.IsStrapped &&
             MemClock.Equals(other.MemClock) &&
             PowerConsumption == other.PowerConsumption &&
             EqualityComparer<IVideoCardSignil>.Default.Equals(VideoCardSignil, other.VideoCardSignil);
    }

    public override int GetHashCode()
    {
      var hashCode = -1822004008;
      hashCode = hashCode * -1521134295 + EqualityComparer<string>.Default.GetHashCode(BIOSVersion);
      hashCode = hashCode * -1521134295 + CoreClock.GetHashCode();
      hashCode = hashCode * -1521134295 + CoreVoltage.GetHashCode();
      hashCode = hashCode * -1521134295 + EqualityComparer<string>.Default.GetHashCode(DeviceID);
      hashCode = hashCode * -1521134295 + IsStrapped.GetHashCode();
      hashCode = hashCode * -1521134295 + MemClock.GetHashCode();
      hashCode = hashCode * -1521134295 + PowerConsumption.GetHashCode();
      hashCode = hashCode * -1521134295 + EqualityComparer<IVideoCardSignil>.Default.GetHashCode(VideoCardSignil);
      return hashCode;
    }

    public static bool operator ==(VideoCard left, VideoCard right)
    {
      return EqualityComparer<VideoCard>.Default.Equals(left, right);
    }

    public static bool operator !=(VideoCard left, VideoCard right)
    {
      return !(left == right);
    }
  }

  [Serializable]
  public class VideoCardSignil :IVideoCardSignil, IEquatable<VideoCardSignil>
  {
    public string CardName { get; }
    public GPUMaker GPUMaker { get; }
    public VideoCardMaker VideoCardMaker { get; }
    public VideoCardMemoryMaker VideoMemoryMaker { get; }
    public int VideoMemorySize { get; }

    public VideoCardSignil()
    {
    }

    public VideoCardSignil(string cardName, GPUMaker gPUMaker, VideoCardMaker videoCardMaker, VideoCardMemoryMaker videoMemoryMaker, int videoMemorySize)
    {
      CardName = cardName ?? throw new ArgumentNullException(nameof(cardName));
      GPUMaker = gPUMaker;
      VideoCardMaker = videoCardMaker;
      VideoMemoryMaker = videoMemoryMaker;
      VideoMemorySize = videoMemorySize;
    }

    public override bool Equals(object obj)
    {
      return Equals(obj as VideoCardSignil);
    }

    public bool Equals(VideoCardSignil other)
    {
      return other != null &&
             CardName == other.CardName &&
             GPUMaker == other.GPUMaker &&
             VideoCardMaker == other.VideoCardMaker &&
             VideoMemoryMaker == other.VideoMemoryMaker &&
             VideoMemorySize == other.VideoMemorySize;
    }

    public override int GetHashCode()
    {
      var hashCode = 268322596;
      hashCode = hashCode * -1521134295 + EqualityComparer<string>.Default.GetHashCode(CardName);
      hashCode = hashCode * -1521134295 + GPUMaker.GetHashCode();
      hashCode = hashCode * -1521134295 + VideoCardMaker.GetHashCode();
      hashCode = hashCode * -1521134295 + VideoMemoryMaker.GetHashCode();
      hashCode = hashCode * -1521134295 + VideoMemorySize.GetHashCode();
      return hashCode;
    }

    public static bool operator ==(VideoCardSignil left, VideoCardSignil right)
    {
      return EqualityComparer<VideoCardSignil>.Default.Equals(left, right);
    }

    public static bool operator !=(VideoCardSignil left, VideoCardSignil right)
    {
      return !(left == right);
    }
  }

  [Serializable]
  public class VideoCardTuningParameters : IVideoCardTuningParameters, IEquatable<VideoCardTuningParameters>
  {
    public VideoCardTuningParameters()
    {
    }

    public VideoCardTuningParameters(UnitsNet.Frequency coreClockDefault, UnitsNet.Frequency coreClockMax, UnitsNet.Frequency coreClockMin, UnitsNet.Frequency memoryClockDefault, UnitsNet.Frequency memoryClockMax, UnitsNet.Frequency memoryClockMin, UnitsNet.ElectricPotentialDc voltageDefault, UnitsNet.ElectricPotentialDc voltageMax, UnitsNet.ElectricPotentialDc voltageMin)
    {
      CoreClockDefault = coreClockDefault;
      CoreClockMax = coreClockMax;
      CoreClockMin = coreClockMin;
      MemoryClockDefault = memoryClockDefault;
      MemoryClockMax = memoryClockMax;
      MemoryClockMin = memoryClockMin;
      VoltageDefault = voltageDefault;
      VoltageMax = voltageMax;
      VoltageMin = voltageMin;
    }

    public UnitsNet.Frequency CoreClockDefault { get; }
    public UnitsNet.Frequency CoreClockMax { get; }
    public UnitsNet.Frequency CoreClockMin { get; }
    public UnitsNet.Frequency MemoryClockDefault { get; }
    public UnitsNet.Frequency MemoryClockMax { get; }
    public UnitsNet.Frequency MemoryClockMin { get; }
    public UnitsNet.ElectricPotentialDc VoltageDefault { get; }
    public UnitsNet.ElectricPotentialDc VoltageMax { get; }
    public UnitsNet.ElectricPotentialDc VoltageMin { get; }

    public override bool Equals(object obj)
    {
      return Equals(obj as VideoCardTuningParameters);
    }

    public bool Equals(VideoCardTuningParameters other)
    {
      return other != null &&
             CoreClockDefault == other.CoreClockDefault &&
             CoreClockMax == other.CoreClockMax &&
             CoreClockMin == other.CoreClockMin &&
             MemoryClockDefault == other.MemoryClockDefault &&
             MemoryClockMax == other.MemoryClockMax &&
             MemoryClockMin == other.MemoryClockMin &&
             VoltageDefault == other.VoltageDefault &&
             VoltageMax == other.VoltageMax &&
             VoltageMin == other.VoltageMin;
    }

    public override int GetHashCode()
    {
      var hashCode = 156220204;
      hashCode = hashCode * -1521134295 + CoreClockDefault.GetHashCode();
      hashCode = hashCode * -1521134295 + CoreClockMax.GetHashCode();
      hashCode = hashCode * -1521134295 + CoreClockMin.GetHashCode();
      hashCode = hashCode * -1521134295 + MemoryClockDefault.GetHashCode();
      hashCode = hashCode * -1521134295 + MemoryClockMax.GetHashCode();
      hashCode = hashCode * -1521134295 + MemoryClockMin.GetHashCode();
      hashCode = hashCode * -1521134295 + VoltageDefault.GetHashCode();
      hashCode = hashCode * -1521134295 + VoltageMax.GetHashCode();
      hashCode = hashCode * -1521134295 + VoltageMin.GetHashCode();
      return hashCode;
    }

    public static bool operator ==(VideoCardTuningParameters left, VideoCardTuningParameters right)
    {
      return EqualityComparer<VideoCardTuningParameters>.Default.Equals(left, right);
    }

    public static bool operator !=(VideoCardTuningParameters left, VideoCardTuningParameters right)
    {
      return !(left == right);
    }
  }



  //ToDo make these thread-safe (concurrent)
  [Serializable]
  public class TempAndFan : ITempAndFan 
  {
    public TempAndFan()
    {
    }

    public TempAndFan(Temperature temp, Ratio fanPct)
    {
      Temp = temp;
      FanPct = fanPct;
    }

    public Temperature Temp { get; set; }
    public Ratio FanPct { get; set; }

  }

  /*
  public class PowerConsumptionConverter : ExpandableObjectConverter
  {
    public override bool CanConvertFrom(
        ITypeDescriptorContext context, Type sourceType)
    {
      if (sourceType == typeof(string))
      {
        return true;
      }
      return base.CanConvertFrom(context, sourceType);
    }

    public override bool CanConvertTo(
        ITypeDescriptorContext context, Type destinationType)
    {
      if (destinationType == typeof(string))
      {
        return true;
      }
      return base.CanConvertTo(context, destinationType);
    }

    public override object ConvertFrom(ITypeDescriptorContext
        context, CultureInfo culture, object value)
    {
      if (value == null)
      {
        return new PowerConsumption();
      }

      if (value is string)
      {
        //ToDo better validation on string to be sure it conforms to  "double-TimeBlock"
        string[] s = ((string)value).Split('-');
        if (s.Length != 2 || !double.TryParse(s[0], out double w) || !TimeSpan.TryParse(s[1], out TimeSpan period))
        {
          throw new ArgumentException("Object is not a string of format double-int",
                                     "value");
        }

        return new PowerConsumption(w, period);
      }

      return base.ConvertFrom(context, culture, value);
    }

    public override object ConvertTo(
        ITypeDescriptorContext context,
        CultureInfo culture, object value, Type destinationType)
    {
      if (value != null)
      {
        if (!(value is PowerConsumption))
        {
          throw new ArgumentException("Invalid object, is not a PowerConsumption", "value");
        }
      }

      if (destinationType == typeof(string))
      {
        if (value == null)
        {
          return string.Empty;
        }

        PowerConsumption powerConsumption = (PowerConsumption)value;
        return powerConsumption.ToString();
      }
      return base.ConvertTo(context,
                            culture,
                            value,
          destinationType);
    }
  }
*/


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
