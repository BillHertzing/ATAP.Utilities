using System;
using System.Collections.Generic;
using System.Runtime.Serialization;
using ATAP.Utilities.ComputerInventory.Enumerations;

namespace ATAP.Utilities.ComputerInventory.Models
{
  [Serializable]
  public class MainBoard : ISerializable
  {
    readonly MainBoardMaker maker;

    readonly string socket;

    MainBoard(SerializationInfo info, StreamingContext ctxt)
    {
      ///ToDo: figure out why the static extension method found in utilities.Enumerations doesn't work
      //this.maker = MainBoardMaker.ToEnum<MainBoardMaker>(info.GetString("Maker"));
      this.maker = (MainBoardMaker)Enum.Parse(typeof(MainBoardMaker), info.GetString("Maker"), true);
      this.socket = info.GetString("Socket");
    }

    public MainBoard(MainBoardMaker maker, string socket)
    {
      this.maker = maker;
      this.socket = socket;
    }

    void ISerializable.GetObjectData(SerializationInfo info, StreamingContext context)
    {
      info.AddValue("Maker", this.Maker.ToString());
      info.AddValue("Socket", this.Socket);
    }

    public MainBoardMaker Maker => maker;

    public string Socket => socket;

    public override bool Equals(Object obj)
    {
      if (obj == null)
        return false;

      MainBoard id = obj as MainBoard;
      if (id == null)
        return false;

      return (maker == id.Maker);
    }

    public override int GetHashCode()
    {
      return maker.GetHashCode();
    }
  }

  [Serializable]
  public class CPU
  {
    readonly CPUMaker maker;
    //public CPU() : this(CPUMaker.Generic) {}
    public CPU(CPUMaker maker)
    {
      this.maker = maker;
    }
    public CPUMaker Maker => maker;

    public override bool Equals(Object obj)
    {
      if (obj == null)
        return false;

      CPU id = obj as CPU;
      if (id == null)
        return false;

      return (maker == id.Maker);
    }

    public override int GetHashCode()
    {
      return maker.GetHashCode();
    }
  }


    [Serializable]
    public class VideoCardSensorData
    {
      double coreClock;
      double coreVoltage;
      double fanRPM;
      double memClock;
      double powerConsumption;
      double powerLimit;
      double temp;

      public VideoCardSensorData() : this(default, default, default, default, default, default, default)
      {
      }
      public VideoCardSensorData(double coreClock, double memClock, double coreVoltage, double powerLimit, double fanRPM, double temp, double powerConsumption)
      {
        this.coreClock = coreClock;
        this.memClock = memClock;
        this.coreVoltage = coreVoltage;
        this.powerLimit = powerLimit;
        this.fanRPM = fanRPM;
        this.temp = temp;
        this.powerConsumption = powerConsumption;
      }

      public double CoreClock { get => coreClock; set => coreClock = value; }
      public double CoreVoltage { get => coreVoltage; set => coreVoltage = value; }
      public double FanRPM { get => fanRPM; set => fanRPM = value; }
      public double MemClock { get => memClock; set => memClock = value; }
      public double PowerConsumption { get => powerConsumption; set => powerConsumption = value; }
      public double PowerLimit { get => powerLimit; set => powerLimit = value; }
      public double Temp { get => temp; set => temp = value; }
    }

    [Serializable]
    public class VideoCard
    {
      readonly string bIOSVersion;
      readonly string deviceID;
      readonly bool isStrapped;
      readonly VideoCardDiscriminatingCharacteristics videoCardDiscriminatingCharacteristics;
      public VideoCard() : this(default, default, default, default, default, default, default, default)
      {
      }
      public VideoCard(
       VideoCardDiscriminatingCharacteristics videoCardDiscriminatingCharacteristics,
       string deviceID,
       string bIOSVersion,
       bool isStrapped,
       double coreClock,
       double memClock,
       double coreVoltage,
       double powerLimit
          )
      {
        this.videoCardDiscriminatingCharacteristics = videoCardDiscriminatingCharacteristics;
        this.deviceID = deviceID;
        this.bIOSVersion = bIOSVersion;
        this.isStrapped = isStrapped;
        CoreClock = coreClock;
        MemClock = memClock;
        CoreVoltage = coreVoltage;
        PowerLimit = powerLimit;
      }

      public string BIOSVersion => bIOSVersion;

      public double CoreClock { get; set; }
      public double CoreVoltage { get; set; }
      public string DeviceID => deviceID;
      public bool IsStrapped => isStrapped;
      public double MemClock { get; set; }
      public double PowerLimit { get; set; }

      public VideoCardDiscriminatingCharacteristics VideoCardDiscriminatingCharacteristics => videoCardDiscriminatingCharacteristics;
    }

    [Serializable]
    public class VideoCardDiscriminatingCharacteristics
    {
      readonly string cardName;
      readonly GPUMaker gPUMaker;
      readonly VideoCardMaker videoCardMaker;
      readonly VideoCardMemoryMaker videoMemoryMaker;
      readonly int videoMemorySize;

      public VideoCardDiscriminatingCharacteristics(VideoCardMaker videoCardMaker, GPUMaker gPUMaker, string cardName, int videoMemorySize, VideoCardMemoryMaker videoMemoryMaker)
      {
        this.videoCardMaker = videoCardMaker;
        this.gPUMaker = gPUMaker;
        this.cardName = cardName;
        this.videoMemorySize = videoMemorySize;
        this.videoMemoryMaker = videoMemoryMaker;
      }

      public string CardName => cardName;

      public GPUMaker GPUMaker => gPUMaker;

      public VideoCardMaker VideoCardMaker => videoCardMaker;

      public VideoCardMemoryMaker VideoMemoryMaker => videoMemoryMaker;

      public int VideoMemorySize => videoMemorySize;
    }

    [Serializable]
    public class VideoCardTuningParameters
    {
      readonly int coreClockDefault;
      readonly int coreClockMax;
      readonly int coreClockMin;
      readonly int memoryClockDefault;
      readonly int memoryClockMax;
      readonly int memoryClockMin;
      readonly double voltageDefault;
      readonly double voltageMax;
      readonly double voltageMin;

      public VideoCardTuningParameters(int memoryClockDefault, int memoryClockMin, int memoryClockMax, int coreClockDefault, int coreClockMin, int coreClockMax, double voltageDefault, double voltageMin, double voltageMax)
      {
        this.memoryClockDefault = memoryClockDefault;
        this.memoryClockMin = memoryClockMin;
        this.memoryClockMax = memoryClockMax;
        this.coreClockDefault = coreClockDefault;
        this.coreClockMin = coreClockMin;
        this.coreClockMax = coreClockMax;
        this.voltageDefault = voltageDefault;
        this.voltageMin = voltageMin;
        this.voltageMax = voltageMax;
      }

      public int CoreClockDefault => coreClockDefault;

      public int CoreClockMax => coreClockMax;

      public int CoreClockMin => coreClockMin;

      public int MemoryClockDefault => memoryClockDefault;

      public int MemoryClockMax => memoryClockMax;

      public int MemoryClockMin => memoryClockMin;

      public double VoltageDefault => voltageDefault;

      public double VoltageMax => voltageMax;

      public double VoltageMin => voltageMin;
    }

    [Serializable]
    public static class VideoCardsKnown
    {
      static readonly Dictionary<VideoCardDiscriminatingCharacteristics, VideoCardTuningParameters> tuningParameters;

      static VideoCardsKnown()
      {
        tuningParameters = new Dictionary<VideoCardDiscriminatingCharacteristics, VideoCardTuningParameters>
            {
                { new VideoCardDiscriminatingCharacteristics(VideoCardMaker.ASUS,
                                                             GPUMaker.NVIDEA,
                                                             "GTX 980 TI",
                                                             6144,
                                                             VideoCardMemoryMaker.Samsung), new VideoCardTuningParameters(810,
                                                                                                                          800,
                                                                                                                          820,
                                                                                                                          405,
                                                                                                                          400,
                                                                                                                          410,
                                                                                                                          0.862,
                                                                                                                          0.80,
                                                                                                                          1.024) },
                { new VideoCardDiscriminatingCharacteristics(VideoCardMaker.MSI,
                                                             GPUMaker.AMD,
                                                             "R9 270",
                                                             2048,
                                                             VideoCardMemoryMaker.Elpida), new VideoCardTuningParameters(1400,
                                                                                                                         1300,
                                                                                                                         1500,
                                                                                                                         955,
                                                                                                                         940,
                                                                                                                         960,
                                                                                                                         1.0,
                                                                                                                         0.98,
                                                                                                                         1.05) },
                { new VideoCardDiscriminatingCharacteristics(VideoCardMaker.MSI,
                                                             GPUMaker.AMD,
                                                             "RX 580",
                                                             8192,
                                                             VideoCardMemoryMaker.Hynix), new VideoCardTuningParameters(1400,
                                                                                                                        1300,
                                                                                                                        1500,
                                                                                                                        955,
                                                                                                                        940,
                                                                                                                        960,
                                                                                                                        1.0,
                                                                                                                        0.98,
                                                                                                                        1.05) },
                { new VideoCardDiscriminatingCharacteristics(VideoCardMaker.MSI,
                                                             GPUMaker.AMD,
                                                             "RX 580",
                                                             8192,
                                                             VideoCardMemoryMaker.Generic), new VideoCardTuningParameters(1400,
                                                                                                                          1300,
                                                                                                                          1500,
                                                                                                                          955,
                                                                                                                          940,
                                                                                                                          960,
                                                                                                                          1.0,
                                                                                                                          0.98,
                                                                                                                          1.05) },
                { new VideoCardDiscriminatingCharacteristics(VideoCardMaker.PowerColor,
                                                             GPUMaker.AMD,
                                                             "RX 580",
                                                             8192,
                                                             VideoCardMemoryMaker.Hynix), new VideoCardTuningParameters(1400,
                                                                                                                        1300,
                                                                                                                        1500,
                                                                                                                        955,
                                                                                                                        940,
                                                                                                                        960,
                                                                                                                        1.0,
                                                                                                                        0.98,
                                                                                                                        1.05) },
                { new VideoCardDiscriminatingCharacteristics(VideoCardMaker.PowerColor,
                                                             GPUMaker.AMD,
                                                             "RX 580",
                                                             8192,
                                                             VideoCardMemoryMaker.Samsung), new VideoCardTuningParameters(1400,
                                                                                                                          1300,
                                                                                                                          1500,
                                                                                                                          955,
                                                                                                                          940,
                                                                                                                          960,
                                                                                                                          1.0,
                                                                                                                          0.98,
                                                                                                                          1.05) },
                { new VideoCardDiscriminatingCharacteristics(VideoCardMaker.Generic,
                                                             GPUMaker.Generic,
                                                             "Generic",
                                                             1024,
                                                             VideoCardMemoryMaker.Generic), new VideoCardTuningParameters(-1,
                                                                                                                          -1,
                                                                                                                          -1,
                                                                                                                          -1,
                                                                                                                          -1,
                                                                                                                          -1,
                                                                                                                          -1,
                                                                                                                          -1,
                                                                                                                          -1)}
            };
      }

      public static Dictionary<VideoCardDiscriminatingCharacteristics, VideoCardTuningParameters> TuningParameters => tuningParameters;
    }

  }

