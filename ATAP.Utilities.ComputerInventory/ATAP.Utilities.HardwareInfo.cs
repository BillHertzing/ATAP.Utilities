using Itenso.TimePeriod;
using OpenHardwareMonitor.Hardware;
using Swordfish.NET.Collections;
using System;
using System.Collections.Generic;
using System.Text;

namespace ATAP.Utilities.ComputerInventory
{
    public class Motherboard
    {
        readonly MotherboardMaker maker;

        readonly string socket;

        public Motherboard(MotherboardMaker maker, string socket)
        {
            this.maker = maker;
            this.socket = socket;
        }

        public MotherboardMaker Maker => maker;

        public string Socket => socket;
    }

    public class CPU
    {
        readonly CPUMaker maker;

        public CPU(CPUMaker maker)
        {
            this.maker = maker;
        }

        public CPUMaker Maker => maker;
    }

    public class VideoCard
    {
        ConcurrentObservableDictionary<string, double> bindableDoubles;
        readonly string bIOSVersion;
        readonly string deviceID;
        readonly bool isStrapped;
        readonly VideoCardDiscriminatingCharacteristics videoCardDiscriminatingCharacteristics;

        public VideoCard(
         VideoCardDiscriminatingCharacteristics videoCardDiscriminatingCharacteristics,
         string deviceID,
         string bIOSVersion,
         bool isStrapped,
         double coreClock,
         double memClock,
         double coreVoltage,
         double powerLimit,
         PowerConsumption powerConsumption,
         TempAndFan tempAndFan
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
            PowerConsumption = powerConsumption;
            TempAndFan = tempAndFan;
            bindableDoubles = new ConcurrentObservableDictionary<string, double>() {
                {"CoreClock", coreClock },
                {"MemClock", memClock },
                {"CoreVoltage", coreVoltage },
                {"PowerLimit", powerLimit },
            };
        }

        ConcurrentObservableDictionary<string, double> BindableDoubles { get => bindableDoubles; }

        public string BIOSVersion => bIOSVersion;

        public double CoreClock { get; set; }
        public double CoreVoltage { get; set; }

        public string DeviceID => deviceID;

        public bool IsStrapped => isStrapped;
        public double MemClock { get; set; }
        public PowerConsumption PowerConsumption { get; set; }
        public double PowerLimit { get; set; }
        public TempAndFan TempAndFan { get; set; }

        public VideoCardDiscriminatingCharacteristics VideoCardDiscriminatingCharacteristics => videoCardDiscriminatingCharacteristics;
    }
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
                                                                                                                          1048,
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

    public class ComputerHW : OpenHardwareMonitor.Hardware.Computer
    {
        readonly OpenHardwareMonitor.Hardware.Computer computer;
        readonly bool isMainboardEnabled;
        readonly bool isCPUsEnabled;
        readonly bool isVideoCardsEnabled;
        readonly CPU[] cPUs;
        readonly Motherboard motherboard;
        readonly VideoCard[] videoCards;

        public ComputerHW(CPU[] cPUs, Motherboard motherboard, VideoCard[] videoCards, TimeBlock instantiation)
        {
            isMainboardEnabled = true;
            isCPUsEnabled = true;
            isVideoCardsEnabled = true;
            this.cPUs = cPUs;
            this.motherboard = motherboard;
            this.videoCards = videoCards;
            Instantiation = instantiation;
        }

        TimeBlock Instantiation { get; set; }

        // ToDo: Add field and property for MotherboardMemory
        // ToDo: Add field and property for Disks
        // ToDo: Add field and property for PowerSupply
        // ToDo: Add field and property for USBPorts


        public Computer Computer => computer;

        public CPU[] CPUs => cPUs;

        public Motherboard Motherboard => motherboard;

        public VideoCard[] VideoCards => videoCards;

        public bool IsMainboardEnabled => isMainboardEnabled;

        public bool IsCPUsEnabled => isCPUsEnabled;

        public bool IsVideoCardsEnabled => isVideoCardsEnabled;
    }
}
