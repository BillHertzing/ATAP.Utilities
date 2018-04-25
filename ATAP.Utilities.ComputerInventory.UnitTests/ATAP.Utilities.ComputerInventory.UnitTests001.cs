using System;
using System.Collections.Generic;
using System.Linq;
using System.Timers;
using FluentAssertions;
using Itenso.TimePeriod;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Xunit;
using Xunit.Abstractions;
using YamlDotNet.Serialization;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{
    public class Fixture
    {
        #region (fields) YAML Serializer/Deserializer
        readonly Serializer serializer = new SerializerBuilder().Build();
        readonly Deserializer deserializer = new DeserializerBuilder().Build();
        #endregion (fields) YAML Serializer/Deserializer

        public ComputerProcesses computerProcesses;
        public int pidUnderTest;

        public Fixture()
        {
            mainBoard = new MainBoard(MainBoardMaker.ASUS, "ToDo:makeSocketanEnum");
            cPU = new CPU(CPUMaker.Intel);
            cPUs = new CPU[1];
            cPUs[0] = cPU;
            videoCardDiscriminatingCharacteristics = VideoCardsKnown.TuningParameters.Keys.Where(x =>
       (x.VideoCardMaker == VideoCardMaker.ASUS && x.GPUMaker == GPUMaker.NVIDEA))
                                                                                                    .Single();
            videoCard = new VideoCard(videoCardDiscriminatingCharacteristics,
                           "ToDo:readfromcard",
                           "ToDo:readfromcard",
                           false,
                           -1,
                           -1,
                           -1,
                           -1
                           );
            videoCards = new VideoCard[1];
            videoCards[0] = videoCard;
            videoCardSensorData = new VideoCardSensorData(1000.0, 1333.0, 1.0, 1.0, 500.0, 85.0, 100.0);
            computerHardware = new ComputerHardware(CPUs, MainBoard, VideoCards);
            JsonConvert.DefaultSettings = () => new JsonSerializerSettings
            {
                DefaultValueHandling = DefaultValueHandling.Include,
                Converters = { new StringEnumConverter() }
            };
        }

        #region (properties) YAML Serializer/Deserializer
        public Serializer Serializer => serializer;
        public Deserializer Deserializer => deserializer;
        #endregion (properties) YAML Serializer/Deserializer

        #region (fields) one example of computer hardware 
        readonly MainBoard mainBoard;
        readonly CPU cPU;
        readonly CPU[] cPUs;
        readonly VideoCardDiscriminatingCharacteristics videoCardDiscriminatingCharacteristics;

        readonly VideoCard videoCard;
        readonly VideoCard[] videoCards;
        readonly VideoCardSensorData videoCardSensorData;
        readonly ComputerHardware computerHardware;
        #endregion (fields) one example of computer hardware 

        #region (properties) one example of computer hardware 
        public CPU CPU => cPU;

        public CPU[] CPUs => cPUs;

        public MainBoard MainBoard => mainBoard;

        public VideoCardDiscriminatingCharacteristics VideoCardDiscriminatingCharacteristics => videoCardDiscriminatingCharacteristics;

        public VideoCard VideoCard => videoCard;

        public VideoCard[] VideoCards => videoCards;

        public ComputerHardware ComputerHardware => computerHardware;

        public VideoCardSensorData VideoCardSensorData => videoCardSensorData;


        #endregion (properties) one example of computer hardware 
    }

    public class ComputerInventoryUnitTests001 : IClassFixture<Fixture>
    {
        readonly ITestOutputHelper output;
        protected Fixture _fixture;

        public ComputerInventoryUnitTests001(ITestOutputHelper output, Fixture fixture)
        {
            this.output = output;
            this._fixture = fixture;
        }

        void HandleTimer(object source, ElapsedEventArgs e)
        {
            _fixture.computerProcesses.Kill(_fixture.pidUnderTest);
        }

        [Theory]
        [InlineData("{\"ComputerHardware\":{\"Computer\":{\"MainboardEnabled\":true,\"CPUEnabled\":true,\"RAMEnabled\":false,\"GPUEnabled\":true,\"FanControllerEnabled\":true,\"HDDEnabled\":false,\"Hardware\":[]},\"CPUs\":[{\"Maker\":\"Intel\"}],\"MainBoard\":{\"Maker\":\"ASUS\",\"Socket\":\"ToDo:makeSocketanEnum\"},\"VideoCards\":[{\"BIOSVersion\":\"ToDo:readfromcard\",\"CoreClock\":-1.0,\"CoreVoltage\":-1.0,\"DeviceID\":\"ToDo:readfromcard\",\"IsStrapped\":false,\"MemClock\":-1.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":-1.0,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardDiscriminatingCharacteristics\":{\"CardName\":\"GTX 980 TI\",\"GPUMaker\":\"NVIDEA\",\"VideoCardMaker\":\"ASUS\",\"VideoMemoryMaker\":\"Samsung\",\"VideoMemorySize\":6144}}],\"IsMainboardEnabled\":true,\"IsCPUsEnabled\":true,\"IsVideoCardsEnabled\":true,\"IsFanControllerEnabled\":true,\"MainboardEnabled\":false,\"CPUEnabled\":false,\"RAMEnabled\":false,\"GPUEnabled\":false,\"FanControllerEnabled\":false,\"HDDEnabled\":false,\"Hardware\":[]},\"ComputerSoftware\":{\"ComputerSoftwareDrivers\":[{\"Name\":\"genericvideo\",\"Version\":\"1.0\"},{\"Name\":\"AMDVideoDriver\",\"Version\":\"1.0\"},{\"Name\":\"NVideaVideoDriver\",\"Version\":\"1.0\"}],\"ComputerSoftwarePrograms\":[{\"ProcessName\":\"EthDCRMiner\",\"ProcessPath\":\"C:\\\\\",\"ProcessStartPath\":\"C:\\\\\",\"Version\":\"10.2\",\"HasConfigurationSettings\":false,\"ConfigurationSettings\":null,\"ConfigFilePath\":null,\"HasLogFiles\":false,\"LogFileFolder\":null,\"LogFileFnPattern\":null,\"HasAPI\":false,\"HasSTDOut\":false,\"HasERROut\":false}]},\"ComputerProcesses\":{}}")]
        internal void ComputerInventorySerializeToJSON(string _testdatainput)
        {
            string str;
            ComputerInventory computerInventory;
            ComputerSoftware computerSoftware;
            ComputerProcesses computerProcesses;

            var computerSoftwareProgram = new ComputerSoftwareProgram("EthDCRMiner",
                                                                      @"C:\",
                                                                      @"C:\",
                                                                      "10.2",
                                                                      false,
                                                                      null,
                                                                      null,
                                                                      false,
                                                                      null,
                                                                      null,
                                                                      false,
                                                                      false,
                                                                      false);
            str = JsonConvert.SerializeObject(computerSoftwareProgram);
            List<ComputerSoftwareProgram> computerSoftwarePrograms = new List<ComputerSoftwareProgram> {
            computerSoftwareProgram
            };
            str = JsonConvert.SerializeObject(computerSoftwarePrograms);
            List<ComputerSoftwareDriver> computerSoftwareDrivers = new List<ComputerSoftwareDriver> {
            new ComputerSoftwareDriver("genericvideo",
                                       "1.0"),
                new ComputerSoftwareDriver("AMDVideoDriver",
                                           "1.0"),
                new
                ComputerSoftwareDriver("NVideaVideoDriver",
                                       "1.0")
            };
            str = JsonConvert.SerializeObject(computerSoftwareDrivers);
            // OperatingSystem os = Environment.OSVersion;
            //str = JsonConvert.SerializeObject(os);
            computerSoftware = new ComputerSoftware(computerSoftwareDrivers, computerSoftwarePrograms);
            str = JsonConvert.SerializeObject(computerSoftware);
            computerProcesses = new ComputerProcesses();
            str = JsonConvert.SerializeObject(computerProcesses);
            computerInventory = new ComputerInventory(_fixture.ComputerHardware, computerSoftware, computerProcesses);
            str = JsonConvert.SerializeObject(computerInventory);
            str.Should()
                .NotBeNull();
            str.Should()
                .Be(_testdatainput);
        }

        [Theory]
        [InlineData("10")]
        public async void ComputerProcessesStartStopTest001(string _testdatainput)
        {
            int specifiedTestRunTime = int.Parse(_testdatainput);
            // ToDo: Need to create a ComputerSoftwareProgram for PowerShell as a builtin, and figure out how to get its path "the right way" 
            ComputerSoftwareProgram powerShell = new ComputerSoftwareProgram("powershell",
                                                                             @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
                                                                             ".",
                                                                             "v5",
                                                                             false,
                                                                             null,
                                                                             null,
                                                                             false,
                                                                             null,
                                                                             null,
                                                                             false,
                                                                             false,
                                                                             false);
            _fixture.computerProcesses = new ComputerProcesses();
            // stop the program in 1/2 of the specified test run time (specifiedTestRunTime is in seconds, timers are in milliseconds)
            Timer aTimer = new Timer(specifiedTestRunTime * 500);
            aTimer.Elapsed += new ElapsedEventHandler(HandleTimer);
            TimeInterval ti = new TimeInterval(System.DateTime.Now);
            _fixture.pidUnderTest = _fixture.computerProcesses.Start(powerShell,
                                                                     new object[2] {
            "-Command",
                $"&{{start-sleep -s {_testdatainput}; exit}}"
            });
            aTimer.Start();
            // wait for the program to stop. The event handler should stop it.
            var p = _fixture.computerProcesses.ComputerProcessDictionary[_fixture.pidUnderTest];
            await p.Cmd.Task;
            ti.ExpandTo(System.DateTime.Now);
            // Dispose of the timer
            aTimer.Dispose();
            var processResult = p.Cmd.Task.Result;
            p.Cmd.Result.ExitCode.Should()
                .Be(-1);
            p.Cmd.Result.Success.Should()
                .Be(false);
            ti.Duration.Should()
                .BeCloseTo(new TimeSpan(0, 0, specifiedTestRunTime / 2), 1000);
        }

        [Theory]
        [InlineData("5")]
        public async void ComputerProcessesStartTest001(string _testdatainput)
        {
            int specifiedTestRunTime = int.Parse(_testdatainput);
            // ToDo: Need to create a ComputerSoftwareProgram for PowerShell as a builtin, and figure out how to get its path "the right way" 
            ComputerSoftwareProgram powerShell = new ComputerSoftwareProgram("powershell",
                                                                             @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
                                                                             ".",
                                                                             "v5",
                                                                             false,
                                                                             null,
                                                                             null,
                                                                             false,
                                                                             null,
                                                                             null,
                                                                             false,
                                                                             false,
                                                                             false);
            _fixture.computerProcesses = new ComputerProcesses();
            TimeInterval ti = new TimeInterval(System.DateTime.Now);
            _fixture.pidUnderTest = _fixture.computerProcesses.Start(powerShell,
                                                                     new object[2] {
            "-Command",
                $"&{{start-sleep -s {_testdatainput}; exit}}"
            });
            // wait for the program to stop
            var p = _fixture.computerProcesses.ComputerProcessDictionary[_fixture.pidUnderTest];
            await p.Cmd.Task;
            ti.ExpandTo(System.DateTime.Now);
            var processResult = p.Cmd.Task.Result;
            p.Cmd.Result.ExitCode.Should()
                .Be(0);
            p.Cmd.Result.Success.Should()
                .Be(true);
            ti.Duration.Should()
                .BeCloseTo(new TimeSpan(0, 0, specifiedTestRunTime), 1000);
        }

        [Theory]
        [InlineData("{\"Period\":\"00:01:00\",\"Watts\":1000.0}")]
        public void PowerConsumptionDeSerializeFromJSON(string _testdatainput)
        {
            PowerConsumption powerConsumption = JsonConvert.DeserializeObject<PowerConsumption>(_testdatainput);
            powerConsumption.Should()
                .NotBeNull();
            powerConsumption.Watts.Should()
                .Be(1000);
            powerConsumption.Period.TotalSeconds.Should()
                .Be(60);
        }
        //ToDo add validation tests to ensure illegal values are not allowed
        [Theory]
        [InlineData("{\"Period\":\"00:01:00\",\"Watts\":1000.0}")]
        public void PowerConsumptionSerializeToJSON(string _testdatainput)
        {
            PowerConsumption pc = new PowerConsumption() { Period = new TimeSpan(0, 1, 0), Watts = 1000.0 };
            var str = JsonConvert.SerializeObject(pc);
            str.Should()
                .NotBeNull();
            str.Should()
                .Be(_testdatainput);
        }

        [Theory]
        [InlineData("[{\"Temp\":20.0,\"FanPct\":0.0},{\"Temp\":50.0,\"FanPct\":50.0},{\"Temp\":85.0,\"FanPct\":100.0}]")]
        public void TempAndFanArrayFromJSON(string _testdatainput)
        {
            var tempAndFans = JsonConvert.DeserializeObject<TempAndFan[]>(_testdatainput);
            tempAndFans.Length.Should()
                .Be(3);
            tempAndFans[0].Temp.Should()
                .Be(20);
            tempAndFans[1].Temp.Should()
                .Be(50);
            tempAndFans[2].Temp.Should()
                .Be(85);
            tempAndFans[0].FanPct.Should()
                .Be(0);
            tempAndFans[1].FanPct.Should()
                .Be(50);
            tempAndFans[2].FanPct.Should()
                .Be(100);
        }
        [Theory]
        [InlineData("{\"Temp\":20.0,\"FanPct\":0.0}")]
        public void TempAndFanDeSerializeFromJSON(string _testdatainput)
        {
            var tempAndFan = JsonConvert.DeserializeObject<TempAndFan>(_testdatainput);
            tempAndFan.Should()
                .NotBeNull();
            tempAndFan.Temp.Should()
                .Be(20);
            tempAndFan.FanPct.Should()
                .Be(0);
        }

        [Theory]
        [InlineData("{\"Temp\":50.0,\"FanPct\":95.5}")]
        public void TempAndFanSerializeToJSON(string _testdatainput)
        {
            TempAndFan tempAndFan = new TempAndFan { Temp = 50, FanPct = 95.5 };
            string str = JsonConvert.SerializeObject(tempAndFan);
            str.Should()
                .NotBeNull();
            str.Should()
                .Be(_testdatainput);
        }
    }
    public class ComputerHardwareUnitTests001 : IClassFixture<Fixture>
    {
        readonly ITestOutputHelper output;
        protected Fixture _fixture;

        public ComputerHardwareUnitTests001(ITestOutputHelper output, Fixture fixture)
        {
            this.output = output;
            this._fixture = fixture;
        }
        [Theory]
        [InlineData("{\"BIOSVersion\":\"100.00001.02320.00\",\"CardName\":\"GTX 980 TI\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":0.8,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardMaker\":\"ASUS\",\"GPUMaker\":\"NVIDEA\"}")]
        internal void VideoCardDeSerializeFromJSON(string _testdatainput)
        {
            VideoCard vc = JsonConvert.DeserializeObject<VideoCard>(_testdatainput);
            vc.Should()
                .NotBeNull();
            vc.DeviceID.Should()
                .Be("10DE 17C8 - 3842");
            vc.BIOSVersion.Should()
                .Be("100.00001.02320.00");
            vc.IsStrapped.Should()
                .Be(false);
            vc.CoreClock.Should()
                .Be(1140);
            vc.MemClock.Should()
                .Be(1753);
            vc.CoreVoltage.Should()
                .Be(11.13);
            vc.PowerLimit.Should()
                .Be(0.8);

        }

        [Theory]
        [InlineData("{\"BIOSVersion\":\"100.00001.02320.00\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerLimit\":0.8,\"VideoCardDiscriminatingCharacteristics\":{\"CardName\":\"GTX 980 TI\",\"GPUMaker\":\"NVIDEA\",\"VideoCardMaker\":\"ASUS\",\"VideoMemoryMaker\":\"Samsung\",\"VideoMemorySize\":6144}}")]
        internal void VideoCardSerializeToJSON(string _testdatainput)
        {
            VideoCardDiscriminatingCharacteristics vcdc = VideoCardsKnown.TuningParameters.Keys.Where(x => (x.VideoCardMaker ==
    VideoCardMaker.ASUS
    && x.GPUMaker ==
    GPUMaker.NVIDEA))
                                                              .Single();
            VideoCard videoCard = new VideoCard(vcdc,
                                                "10DE 17C8 - 3842",
                                                "100.00001.02320.00",
                                                false,
                                                1140,
                                                1753,
                                                11.13,
                                                0.8);
            string str = JsonConvert.SerializeObject(videoCard);
            str.Should()
                .NotBeNull();
            str.Should()
                .Be(_testdatainput);
        }
        [Fact]
        public void CPUDeserializeFromJSON()
        {
            CPU cPU = JsonConvert.DeserializeObject<CPU>(JsonConvert.SerializeObject(_fixture.CPU));
            cPU.Should()
                .Be(_fixture.CPU);
        }
        [Fact]
        public void CPUDeserializeFromYAML()
        {
            CPU cPU  = _fixture.Deserializer.Deserialize<CPU>(_fixture.Serializer.Serialize(_fixture.CPU));
            cPU.Should()
                .Be(_fixture.CPU);
        }
        [Theory]
        [InlineData("CPUMaker: Intel\r\n")]
        public void CPUSerializeToYAML(string _testdatainput)
        {
            var yaml = _fixture.Serializer.Serialize(_fixture.CPU);
            yaml.Should()
                .Be(_testdatainput);
        }
        [Fact]
        public void CPUsDeserializeFromJSON()
        {
            CPU[] cPUs = JsonConvert.DeserializeObject<CPU[]>(JsonConvert.SerializeObject(_fixture.CPUs));
            cPUs.Length.Should().Be(_fixture.CPUs.Length);
            for (var i = 0; i < cPUs.Length; i++)
            {
                cPUs[i].Should().Be(_fixture.CPUs[i]);
            }
        }
        [Fact]
        public void CPUsDeserializeFromYAML()
        {
            CPU[] cPUs = _fixture.Deserializer.Deserialize<CPU[]>(_fixture.Serializer.Serialize(_fixture.CPUs));
            cPUs.Length.Should()
                .Be(_fixture.CPUs.Length);
            cPUs[1].Should()
                .Be(_fixture.CPUs);
        }
        [Theory]
        [InlineData("- Maker: Intel\r\n")]
        public void CPUsSerializeToYAML(string _testdatainput)
        {
            var yaml = _fixture.Serializer.Serialize(_fixture.CPUs);
            yaml.Should()
                .Be(_testdatainput);
        }

        [Fact]
        public void MainBoardDeserializeFromJSON()
        {
            MainBoard mainBoard = JsonConvert.DeserializeObject<MainBoard>(JsonConvert.SerializeObject(_fixture.MainBoard));
            mainBoard.Should()
                .Be(_fixture.MainBoard);
        }

        [Theory]
        [InlineData("Maker: ASUS\r\nSocket: ToDo:makeSocketanEnum\r\n")]
        public void MainBoardSerializeToYAML(string _testdatainput)
        {
            var yaml = _fixture.Serializer.Serialize(_fixture.MainBoard);
            yaml.Should()
                .Be(_testdatainput);
        }
        [Theory]
        [InlineData("Computer:\r\n  MainboardEnabled: true\r\n  CPUEnabled: true\r\n  GPUEnabled: true\r\n  FanControllerEnabled: true\r\n  Hardware: &o0 []\r\nCPUs:\r\n- Maker: Intel\r\nMainBoard:\r\n  Maker: ASUS\r\n  Socket: ToDo:makeSocketanEnum\r\nVideoCards:\r\n- BIOSVersion: ToDo:readfromcard\r\n  CoreClock: -1\r\n  CoreVoltage: -1\r\n  DeviceID: ToDo:readfromcard\r\n  MemClock: -1\r\n  PowerConsumption:\r\n    Period: 00:01:00\r\n    Watts: 1000\r\n  PowerLimit: -1\r\n  TempAndFan:\r\n    Temp: 60\r\n    FanPct: 50\r\n  VideoCardDiscriminatingCharacteristics:\r\n    CardName: GTX 980 TI\r\n    GPUMaker: NVIDEA\r\n    VideoCardMaker: ASUS\r\n    VideoMemoryMaker: Samsung\r\n    VideoMemorySize: 6144\r\nIsMainboardEnabled: true\r\nIsCPUsEnabled: true\r\nIsVideoCardsEnabled: true\r\nIsFanControllerEnabled: true\r\nMoment:\r\n  IsReadOnly: true\r\n  IsMoment: true\r\n  HasStart: true\r\n  Start: 2018-02-08T00:40:45.2945614Z\r\n  HasEnd: true\r\n  End: 2018-02-08T00:40:45.2945614Z\r\n  DurationDescription: ''\r\nHardware: *o0\r\n")]
        public void ComputerHardwareSerializeToYAML(string _testdatainput)
        {
            var yaml = _fixture.Serializer.Serialize(_fixture.ComputerHardware);
            yaml.Should()
                .Be(_testdatainput);
        }
        [Theory]
        [InlineData("CardName: GTX 980 TI\r\nGPUMaker: NVIDEA\r\nVideoCardMaker: ASUS\r\nVideoMemoryMaker: Samsung\r\nVideoMemorySize: 6144\r\n")]
        public void VideoCardDiscriminatingCharacteristicsSerializeToYAML(string _testdatainput)
        {
            var yaml = _fixture.Serializer.Serialize(_fixture.VideoCardDiscriminatingCharacteristics);
            yaml.Should()
                .Be(_testdatainput);
        }
        [Theory]
        [InlineData("BIOSVersion: ToDo:readfromcard\r\nCoreClock: -1\r\nCoreVoltage: -1\r\nDeviceID: ToDo:readfromcard\r\nMemClock: -1\r\nPowerLimit: -1\r\nVideoCardDiscriminatingCharacteristics:\r\n  CardName: GTX 980 TI\r\n  GPUMaker: NVIDEA\r\n  VideoCardMaker: ASUS\r\n  VideoMemoryMaker: Samsung\r\n  VideoMemorySize: 6144\r\n")]
        public void VideoCardSerializeToYAML(string _testdatainput)
        {
            var yaml = _fixture.Serializer.Serialize(_fixture.VideoCard);
            yaml.Should()
                .Be(_testdatainput);
        }
        [Theory]
        [InlineData("- BIOSVersion: ToDo:readfromcard\r\n  CoreClock: -1\r\n  CoreVoltage: -1\r\n  DeviceID: ToDo:readfromcard\r\n  MemClock: -1\r\n  PowerLimit: -1\r\n  VideoCardDiscriminatingCharacteristics:\r\n    CardName: GTX 980 TI\r\n    GPUMaker: NVIDEA\r\n    VideoCardMaker: ASUS\r\n    VideoMemoryMaker: Samsung\r\n    VideoMemorySize: 6144\r\n")]
        public void VideoCardsSerializeToYAML(string _testdatainput)
        {
            var yaml = _fixture.Serializer.Serialize(_fixture.VideoCards);
            yaml.Should()
                .Be(_testdatainput);
        }
        [Fact]
        public void VideoCardsDeserializeFromYAML()
        {
            VideoCard[] videoCards = _fixture.Deserializer.Deserialize<VideoCard[]>(_fixture.Serializer.Serialize(_fixture.VideoCards));
            videoCards.Length.Should().Be(1);
            videoCards[0].Should()
                .Be(_fixture.VideoCard);
        }
        [Theory]
        [InlineData("CoreClock: 1000\r\nMemClock: 1333\r\nCoreVoltage: 1\r\nPowerLimit: 1\r\nFanRPM: 500\r\nTemp: 85\r\nPowerConsumption: 100\r\n")]
        public void VideoCardSensorDataSerializeToYAML(string _testdatainput)
        {
            var yaml = _fixture.Serializer.Serialize(_fixture.VideoCardSensorData);
            yaml.Should()
                .Be(_testdatainput);
        }
        [Fact]
        public void VideoCardSensorDataDeSerializeFromYAML()
        {
            VideoCardSensorData videoCardSensorData = _fixture.Deserializer.Deserialize<VideoCardSensorData>(_fixture.Serializer.Serialize(_fixture.VideoCardSensorData));
            videoCardSensorData.Should()
                .Be(_fixture.VideoCardSensorData);
        }
    }
}
