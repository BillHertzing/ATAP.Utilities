using System;
using System.Linq;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Models;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using YamlDotNet.Serialization;

namespace ATAP.Utilities.ComputerInventory.UnitTests.YAML {
    public class Fixture {
        public ComputerProcesses computerProcesses;
    public int pidUnderTest;

    public Fixture() {
        mainBoard = new MainBoard(MainBoardMaker.ASUS, "ToDo:makeSocketanEnum");
      cPU = new CPU(CPUMaker.Intel);
      cPUs = new CPU[1];
      cPUs[0] = cPU;
      videoCardDiscriminatingCharacteristics = VideoCardsKnown.TuningParameters.Keys.Where(x => (x.VideoCardMaker ==
          VideoCardMaker.ASUS
          && x.GPUMaker == GPUMaker.NVIDEA))
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
    }

    #region (fields) YAML Serializer/Deserializer
    readonly Serializer serializer = new SerializerBuilder().Build() as Serializer;
    readonly Deserializer deserializer = new DeserializerBuilder().Build() as Deserializer;
    #endregion (fields) YAML Serializer/Deserializer


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

  public class ComputerInventoryUnitTestsYAML : IClassFixture<Fixture>
  {
    readonly ITestOutputHelper output;
    protected Fixture _fixture;

    public ComputerInventoryUnitTestsYAML(ITestOutputHelper output, Fixture fixture)
    {
      this.output = output;
      this._fixture = fixture;
    }
  }
    public class ComputerHardwareUnitTestsYAML : IClassFixture<Fixture> {
        readonly ITestOutputHelper output;
      protected Fixture _fixture;

      public ComputerHardwareUnitTestsYAML(ITestOutputHelper output, Fixture fixture) {
          this.output = output;
        this._fixture = fixture;
      }

      [Theory]
      [InlineData("Computer:\r\n  MainboardEnabled: true\r\n  CPUEnabled: true\r\n  GPUEnabled: true\r\n  FanControllerEnabled: true\r\n  Hardware: &o0 []\r\nCPUs:\r\n- Maker: Intel\r\nMainBoard:\r\n  Maker: ASUS\r\n  Socket: ToDo:makeSocketanEnum\r\nVideoCards:\r\n- BIOSVersion: ToDo:readfromcard\r\n  CoreClock: -1\r\n  CoreVoltage: -1\r\n  DeviceID: ToDo:readfromcard\r\n  MemClock: -1\r\n  PowerConsumption:\r\n    Period: 00:01:00\r\n    Watts: 1000\r\n  PowerLimit: -1\r\n  TempAndFan:\r\n    Temp: 60\r\n    FanPct: 50\r\n  VideoCardDiscriminatingCharacteristics:\r\n    CardName: GTX 980 TI\r\n    GPUMaker: NVIDEA\r\n    VideoCardMaker: ASUS\r\n    VideoMemoryMaker: Samsung\r\n    VideoMemorySize: 6144\r\nIsMainboardEnabled: true\r\nIsCPUsEnabled: true\r\nIsVideoCardsEnabled: true\r\nIsFanControllerEnabled: true\r\nMoment:\r\n  IsReadOnly: true\r\n  IsMoment: true\r\n  HasStart: true\r\n  Start: 2018-02-08T00:40:45.2945614Z\r\n  HasEnd: true\r\n  End: 2018-02-08T00:40:45.2945614Z\r\n  DurationDescription: ''\r\nHardware: *o0\r\n")]
      public void ComputerHardwareSerializeToYAML(string _testdatainput) {
          var yaml = _fixture.Serializer.Serialize(_fixture.ComputerHardware);
        yaml.Should()
            .Be(_testdatainput);
      }

      [Fact]
      public void CPUDeserializeFromYAML() {
          CPU cPU = _fixture.Deserializer.Deserialize<CPU>(_fixture.Serializer.Serialize(_fixture.CPU));
        cPU.Should()
            .Be(_fixture.CPU);
      }
      [Fact]
      public void CPUsDeserializeFromYAML() {
          CPU[] cPUs = _fixture.Deserializer.Deserialize<CPU[]>(_fixture.Serializer.Serialize(_fixture.CPUs));
        cPUs.Length.Should()
            .Be(_fixture.CPUs.Length);
        cPUs[1].Should()
            .Be(_fixture.CPUs);
      }
      [Theory]
      [InlineData("CPUMaker: Intel\r\n")]
      public void CPUSerializeToYAML(string _testdatainput) {
          var yaml = _fixture.Serializer.Serialize(_fixture.CPU);
        yaml.Should()
            .Be(_testdatainput);
      }
      [Theory]
      [InlineData("- Maker: Intel\r\n")]
      public void CPUsSerializeToYAML(string _testdatainput) {
          var yaml = _fixture.Serializer.Serialize(_fixture.CPUs);
        yaml.Should()
            .Be(_testdatainput);
      }

      [Theory]
      [InlineData("Maker: ASUS\r\nSocket: ToDo:makeSocketanEnum\r\n")]
      public void MainBoardSerializeToYAML(string _testdatainput) {
          var yaml = _fixture.Serializer.Serialize(_fixture.MainBoard);
        yaml.Should()
            .Be(_testdatainput);
      }
      [Theory]
      [InlineData("CardName: GTX 980 TI\r\nGPUMaker: NVIDEA\r\nVideoCardMaker: ASUS\r\nVideoMemoryMaker: Samsung\r\nVideoMemorySize: 6144\r\n")]
      public void VideoCardDiscriminatingCharacteristicsSerializeToYAML(string _testdatainput) {
          var yaml = _fixture.Serializer.Serialize(_fixture.VideoCardDiscriminatingCharacteristics);
        yaml.Should()
            .Be(_testdatainput);
      }
      [Fact]
      public void VideoCardsDeserializeFromYAML() {
          VideoCard[] videoCards = _fixture.Deserializer.Deserialize<VideoCard[]>(_fixture.Serializer.Serialize(_fixture.VideoCards));
        videoCards.Length.Should()
            .Be(1);
        videoCards[0].Should()
            .Be(_fixture.VideoCard);
      }
      [Fact]
      public void VideoCardSensorDataDeSerializeFromYAML() {
          VideoCardSensorData videoCardSensorData = _fixture.Deserializer.Deserialize<VideoCardSensorData>(_fixture.Serializer.Serialize(_fixture.VideoCardSensorData));
        videoCardSensorData.Should()
            .Be(_fixture.VideoCardSensorData);
      }
      [Theory]
      [InlineData("CoreClock: 1000\r\nMemClock: 1333\r\nCoreVoltage: 1\r\nPowerLimit: 1\r\nFanRPM: 500\r\nTemp: 85\r\nPowerConsumption: 100\r\n")]
      public void VideoCardSensorDataSerializeToYAML(string _testdatainput) {
          var yaml = _fixture.Serializer.Serialize(_fixture.VideoCardSensorData);
        yaml.Should()
            .Be(_testdatainput);
      }
      [Theory]
      [InlineData("BIOSVersion: ToDo:readfromcard\r\nCoreClock: -1\r\nCoreVoltage: -1\r\nDeviceID: ToDo:readfromcard\r\nMemClock: -1\r\nPowerLimit: -1\r\nVideoCardDiscriminatingCharacteristics:\r\n  CardName: GTX 980 TI\r\n  GPUMaker: NVIDEA\r\n  VideoCardMaker: ASUS\r\n  VideoMemoryMaker: Samsung\r\n  VideoMemorySize: 6144\r\n")]
      public void VideoCardSerializeToYAML(string _testdatainput) {
          var yaml = _fixture.Serializer.Serialize(_fixture.VideoCard);
        yaml.Should()
            .Be(_testdatainput);
      }
      [Theory]
      [InlineData("- BIOSVersion: ToDo:readfromcard\r\n  CoreClock: -1\r\n  CoreVoltage: -1\r\n  DeviceID: ToDo:readfromcard\r\n  MemClock: -1\r\n  PowerLimit: -1\r\n  VideoCardDiscriminatingCharacteristics:\r\n    CardName: GTX 980 TI\r\n    GPUMaker: NVIDEA\r\n    VideoCardMaker: ASUS\r\n    VideoMemoryMaker: Samsung\r\n    VideoMemorySize: 6144\r\n")]
      public void VideoCardsSerializeToYAML(string _testdatainput) {
          var yaml = _fixture.Serializer.Serialize(_fixture.VideoCards);
        yaml.Should()
            .Be(_testdatainput);
      }
    }
}
