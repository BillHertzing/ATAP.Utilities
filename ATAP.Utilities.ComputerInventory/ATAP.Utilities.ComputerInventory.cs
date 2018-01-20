using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using Itenso.TimePeriod;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Swordfish.NET.Collections;

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

    public class ComputerInventory
    {
        readonly CPU[] cPUs;
        readonly Motherboard motherboard;
        readonly VideoCard[] videoCards;

        public ComputerInventory(CPU[] cPUs, Motherboard motherboard, VideoCard[] videoCards, TimeBlock instantiation)
        {
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
        public static ComputerInventory InventoryThisComputer()
        {
            throw new NotImplementedException();
        }
        //ToDo: Implement writing a ComputerInventory object to ConfigurationSettings
        public static void SetComputerInventoryToConfigurationSettings(ComputerInventory computerInventory) {
            throw new NotImplementedException();
        }
        //ToDo: Implement creating a ComputerInventory object from ConfigurationSettings
        public ComputerInventory ThisComputerInventoryFromConfigurationSettings()
        {
            ComputerInventory ci;
            Motherboard motherboard;
            CPU[] cPUs;
            VideoCard vc;
            int numVideoCards;
            VideoCard[] videoCards;
            switch(Environment.GetEnvironmentVariable("COMPUTERNAME"))
            {
                case "NCAT016":
                    motherboard = new Motherboard(MotherboardMaker.ASUS, "ToDo:makeSocketanEnum");
                    cPUs = new CPU[1] { new CPU(CPUMaker.Intel) };
                    VideoCardDiscriminatingCharacteristics vcdc = KnownVideoCards.TuningParameters.Keys.Where(x => (x.VideoCardMaker ==
                        VideoCardMaker.ASUS
                        && x.GPUMaker ==
                        GPUMaker.NVIDEA))
                                                                      .Single();
                    vc = new VideoCard(vcdc,
                                       "ToDo:readfromcard",
                                       "ToDo:readfromcard",
                                       false,
                                       -1,
                                       -1,
                                       -1,
                                       -1,
                                       new PowerConsumption() {
                    Period =
                        new TimeSpan(0,
                                     1,
                                     0),
                        Watts = 1000
                    },
                                       new TempAndFan() { FanPct = 50.0, Temp = 60 });
                    numVideoCards = 1;
                    videoCards = new VideoCard[1] { vc };
                    ci = new ComputerInventory(cPUs, motherboard, videoCards, new TimeBlock(DateTime.UtcNow));
                    break;
                default:
                    throw new ArgumentException("unknown hostname");
                    //break;
            }
            return ci;
        }

        public CPU[] CPUs => cPUs;

        public Motherboard Motherboard => motherboard;

        public VideoCard[] VideoCards => videoCards;
    }

    public enum GPUMaker
    {
        //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
        [Description("Generic")]
        Generic,
        [Description("AMD")]
        AMD,
        [Description("NVIDEA")]
        NVIDEA
    }

    [JsonConverter(typeof(StringEnumConverter))]
    public enum VideoCardMaker
    {
        //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
        [Description("Generic")]
        Generic,
        [Description("ASUS")]
        ASUS,
        [Description("EVGA")]
        EVGA,
        [Description("MSI")]
        MSI,
        [Description("PowerColor")]
        PowerColor
    }

    [JsonConverter(typeof(StringEnumConverter))]
    public enum MotherboardMaker
    {
        //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
        [Description("Generic")]
        Generic,
        [Description("ASUS")]
        ASUS,
        [Description("MSI")]
        MSI
    }

    [JsonConverter(typeof(StringEnumConverter))]
    public enum CPUMaker
    {
        //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
        [Description("Generic")]
        Generic,
        [Description("Intel")]
        Intel,
        [Description("AMD")]
        AMD
    }

    public enum VideoCardMemoryMaker
    {
        //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
        [Description("Generic")]
        Generic,
        [Description("Elpida")]
        Elpida,
        [Description("Hynix")]
        Hynix,
        [Description("Samsung")]
        Samsung
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

    public static class KnownVideoCards
    {
        static readonly Dictionary<VideoCardDiscriminatingCharacteristics, VideoCardTuningParameters> tuningParameters;

        static KnownVideoCards()
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

// Add an enumeration for the supported cpu names
    // Add an enumeration for the supported cpu sockets
    // Add an enumeration for the supported motherboardMemorymakers
    // Add an enumeration for the supported Disk makers
    // Add an enumeration for the supported Powersupply makers

/*
Abstract:
ComputerInventory
Moment or span?
Motherboard
CPU
Memory
Disks
PowerSupply
USBPorts
VideoCards
Software
Drivers
Mining Programs (includes both name and version)
AceAgent

Concrete:
"FactoryReset", AKA AllDummy (moment, 1/1/1980)
"CurrentActual" (span, from start of program (or last change) to now())
"Profile or hypothetical" (span or moment, can include planned time spans)

ConcurrentObservableDictionary<TimePeriod, ComputerInventory> changeHistoryComputerInventory (each has non-overlapping periods, should be in the aggregate a contiguous span).

*****
Current actual Inventory
is there a changeHistoryComputerInventory in the configuration settings, or a ChangeHistoryComputerInventoryFile (or DB)?
yes - create and load a change history object, make currentActual = latest history
is there a currentComputerInventory in the configuration settings, or a CurrentComputerInventoryFile (or DB)?
yes - compare currentActual
if there is nothing, currentComputerInventory = FactoryReset, and changeHistory = currentComputerInventory
create foundComputerInventory ( run the take inventory method)
if foundComputerInventory == currentComputerInventory, done, else currentComputerInventory = foundComputerInventory and add currentComputerInventory to changeHistoryComputerInventory
at this point, the currentComputerInventory object is up to date

* */
}
