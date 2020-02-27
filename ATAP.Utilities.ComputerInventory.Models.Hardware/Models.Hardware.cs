using System;
using Itenso.TimePeriod;
using ATAP.Utilities.ComputerInventory.Enumerations;
using System.Collections.Generic;
using System.Runtime.Serialization;
using System.ComponentModel;
using System.Globalization;
using ATAP.Utilities.ComputerInventory.Interfaces.Hardware;
using UnitsNet;
using UnitsNet.Units;

namespace ATAP.Utilities.ComputerInventory.Configuration.Hardware
{

  /*
  public class DiskDrivePartitionDriveLetterIdentifier {
      public DiskDrivePartitionDriveLetterIdentifier() : { }
      public DiskDrivePartitionDriveLetterIdentifier(IDictionary<Guid, IDictionary<Guid, string>> diskDrivePartitionInfoGuidsDriveLetterStrings) { DiskDrivePartitionInfoGuidsDriveLetterStrings=diskDrivePartitionInfoGuidsDriveLetterStrings; }
      public IDictionary<Guid, IDictionary<Guid, string>> DiskDrivePartitionInfoGuidsDriveLetterStrings { get; set; }
  }
  */

  [Serializable]
  public class MainBoard : ISerializable, IMainBoard
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

    public MainBoardMaker Maker { get; }

    public CPUSocket CPUSocket { get;  }

    public override bool Equals(Object obj)
    {
      if (obj == null)
      {
        return false;
      }

      if (!(obj is MainBoard id))
      {
        return false;
      }

      return (Maker == id.Maker && CPUSocket == id.CPUSocket);
    }

    //ToDo: add CPUSocket field, figure out how to hash together two fields
    public override int GetHashCode()
    {
      return Maker.GetHashCode();
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


  [Serializable]
  public class VideoCardSensorData : IVideoCardSensorData, IEquatable<VideoCardSensorData>
  {
    public VideoCardSensorData()
    {
    }

    public VideoCardSensorData(double coreClock, double coreVoltage, double fanRPM, double memClock, double powerConsumption, double powerLimit, double temp)
    {
      CoreClock = coreClock;
      CoreVoltage = coreVoltage;
      FanRPM = fanRPM;
      MemClock = memClock;
      PowerConsumption = powerConsumption;
      PowerLimit = powerLimit;
      Temp = temp;
    }

    public double CoreClock { get; }
    public double CoreVoltage { get; }
    public double FanRPM { get; }
    public double MemClock { get; }
    public double PowerConsumption { get; }
    public double PowerLimit { get; }
    public double Temp { get; }

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

    public VideoCard(string bIOSVersion, Frequency coreClock, ElectricPotentialDcUnit coreVoltage, string deviceID, bool isStrapped, Frequency memClock, PowerUnit powerLimit, IVideoCardDiscriminatingCharacteristics videoCardDiscriminatingCharacteristics)
    {
      BIOSVersion = bIOSVersion ?? throw new ArgumentNullException(nameof(bIOSVersion));
      CoreClock = coreClock;
      CoreVoltage = coreVoltage;
      DeviceID = deviceID ?? throw new ArgumentNullException(nameof(deviceID));
      IsStrapped = isStrapped;
      MemClock = memClock;
      PowerLimit = powerLimit;
      VideoCardDiscriminatingCharacteristics = videoCardDiscriminatingCharacteristics ?? throw new ArgumentNullException(nameof(videoCardDiscriminatingCharacteristics));
    }

    public string BIOSVersion { get; }
    public UnitsNet.Frequency CoreClock { get; }
    public UnitsNet.Units.ElectricPotentialDcUnit CoreVoltage { get; }
    public string DeviceID { get; }
    public bool IsStrapped { get; }
    public UnitsNet.Frequency MemClock { get; }
    public UnitsNet.Units.PowerUnit PowerLimit { get; }
    public IVideoCardDiscriminatingCharacteristics VideoCardDiscriminatingCharacteristics { get; }

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
             PowerLimit == other.PowerLimit &&
             EqualityComparer<IVideoCardDiscriminatingCharacteristics>.Default.Equals(VideoCardDiscriminatingCharacteristics, other.VideoCardDiscriminatingCharacteristics);
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
      hashCode = hashCode * -1521134295 + PowerLimit.GetHashCode();
      hashCode = hashCode * -1521134295 + EqualityComparer<IVideoCardDiscriminatingCharacteristics>.Default.GetHashCode(VideoCardDiscriminatingCharacteristics);
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
  public class VideoCardDiscriminatingCharacteristics :IVideoCardDiscriminatingCharacteristics, IEquatable<VideoCardDiscriminatingCharacteristics>
  {
    public string CardName { get; }
    public GPUMaker GPUMaker { get; }
    public VideoCardMaker VideoCardMaker { get; }
    public VideoCardMemoryMaker VideoMemoryMaker { get; }
    public int VideoMemorySize { get; }

    public VideoCardDiscriminatingCharacteristics()
    {
    }

    public VideoCardDiscriminatingCharacteristics(string cardName, GPUMaker gPUMaker, VideoCardMaker videoCardMaker, VideoCardMemoryMaker videoMemoryMaker, int videoMemorySize)
    {
      CardName = cardName ?? throw new ArgumentNullException(nameof(cardName));
      GPUMaker = gPUMaker;
      VideoCardMaker = videoCardMaker;
      VideoMemoryMaker = videoMemoryMaker;
      VideoMemorySize = videoMemorySize;
    }

    public override bool Equals(object obj)
    {
      return Equals(obj as VideoCardDiscriminatingCharacteristics);
    }

    public bool Equals(VideoCardDiscriminatingCharacteristics other)
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

    public static bool operator ==(VideoCardDiscriminatingCharacteristics left, VideoCardDiscriminatingCharacteristics right)
    {
      return EqualityComparer<VideoCardDiscriminatingCharacteristics>.Default.Equals(left, right);
    }

    public static bool operator !=(VideoCardDiscriminatingCharacteristics left, VideoCardDiscriminatingCharacteristics right)
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

    // The IObservable provider objects, classes, and methods
    // attribution:  https://docs.microsoft.com/en-us/dotnet/standard/events/how-to-implement-a-provider
    // Stephen Cleary Concurrent C# recommends using Rx (Reactive) instead of observables
    //List<IObserver<TempAndFan>> Observers { get; }
    //private class Unsubscriber : IDisposable
    //{
    //  List<IObserver<TempAndFan>> Observers { get; }
    //  private IObserver<TempAndFan> Observer { get; }

    //  public Unsubscriber(List<IObserver<TempAndFan>> observers, IObserver<TempAndFan> observer)
    //  {
    //    Observers = observers ?? throw new ArgumentNullException(nameof(observers));
    //    Observer = observer ?? throw new ArgumentNullException(nameof(observer));
    //  }

    //  public void Dispose()
    //  {
    //    if (!(Observer == null))
    //    {
    //      Observers.Remove(Observer);
    //    }
    //  }
    //}

    //public IDisposable Subscribe(IObserver<ITempAndFan> observer)
    //{
    //  if (!Observers.Contains(observer))
    //  {
    //    Observers.Add(observer);
    //  }

    //  return new Unsubscriber(Observers, observer);
    //}
    //public void NotifyObservers()
    //{
    //  //ToDo implement the method that gets a TempAndFan instance update
    //  throw new NotImplementedException();
    //  //foreach (var observer in observers)
    //  //  observer.OnNext(tempAndFanData); // An event should trigger this, and pass in a TempAndFan instance named tempAndFanData
    //  //}
    //  //foreach (var observer in observers.ToArray())
    //  //if (observer != null) observer.OnCompleted(); // this is the code to use if the instance will never send data again
    //  //}
    //  //observers.Clear();
    //}


  }

  /*  an example of an observer
   *  // Attrobution: https://docs.microsoft.com/en-us/dotnet/standard/events/how-to-implement-an-observer
  public class TempAndFanReporter : IObserver<TempAndFan>
  {
    private IDisposable unsubscriber;
    private bool first = true;
    private TempAndFan last;

    public virtual void Subscribe(IObservable<TempAndFan> provider)
    {
      unsubscriber = provider.Subscribe(this);
    }

    public virtual void Unsubscribe()
    {
      unsubscriber.Dispose();
    }

    public virtual void OnCompleted()
    {
      //ToDo: use the action delegate passed into this class's constructor
      //Console.WriteLine("Additional TempAndFan data will not be transmitted.");
      throw new NotImplementedException();
    }

    public virtual void OnError(Exception error)
    {
      // Do nothing.
    }

    public virtual void OnNext(TempAndFan value)
    {
      //ToDo: use the action delegate passed into this class's constructor
      //Console.WriteLine("{0} value.Temp .");
      throw new NotImplementedException();
    }
  }
  */
  //ToDo make these thread-safe (concurrent)
  public class PowerConsumption : IPowerConsumption
  {
    TimeSpan period;
    double watts;

    public PowerConsumption()
    {
      this.watts = default;
      this.period = default;
    }
    public PowerConsumption(double w, TimeSpan period)
    {
      this.watts = w;
      this.period = period;
    }

    public override string ToString()
    {
      return $"{this.watts}-{this.period}";
    }

    public TimeSpan Period { get => period; set => period = value; }
    public double Watts { get => watts; set => watts = value; }

    // The IObservable provider objects, classes, and methods
    // attribution:  https://docs.microsoft.com/en-us/dotnet/standard/events/how-to-implement-a-provider
    List<IObserver<IPowerConsumption>> Observers { get; }
    private class Unsubscriber : IDisposable
    {
      List<IObserver<IPowerConsumption>> Observers { get; }
      private IObserver<IPowerConsumption> Observer { get; }

      public Unsubscriber(List<IObserver<IPowerConsumption>> observers, IObserver<IPowerConsumption> observer)
      {
        Observers = observers ?? throw new ArgumentNullException(nameof(observers));
        Observer = observer ?? throw new ArgumentNullException(nameof(observer));
      }

      public void Dispose()
      {
        if (!(Observer == null))
        {
          Observers.Remove(Observer);
        }
      }
    }

    public IDisposable Subscribe(IObserver<IPowerConsumption> observer)
    {
      if (!Observers.Contains(observer))
      {
        Observers.Add(observer);
      }

      return new Unsubscriber(Observers, observer);
    }
    public void NotifyObservers()
    {
      //ToDo implement the method that gets a TempAndFan instance update
      throw new NotImplementedException();
      //foreach (var observer in observers)
      //  observer.OnNext(tempAndFanData); // An event should trigger this, and pass in a TempAndFan instance named tempAndFanData
      //}
      //foreach (var observer in observers.ToArray())
      //if (observer != null) observer.OnCompleted(); // this is the code to use if the instance will never send data again
      //}
      //observers.Clear();
    }


  }
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
    public TimeBlock Moment { get; }
    public IVideoCard[] VideoCards { get; }

    // ToDo: Add field and property for MainBoardMemory
    // ToDo: Add field and property for Disks
    // ToDo: Add field and property for PowerSupply
    // ToDo: Add field and property for USBPorts

  }
}
