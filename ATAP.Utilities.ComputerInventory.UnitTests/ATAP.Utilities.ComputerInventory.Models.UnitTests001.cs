using System;
using System.Collections.Generic;
using System.Linq;
using System.Timers;
using FluentAssertions;
using Itenso.TimePeriod;
using ServiceStack.Text;
using static ServiceStack.Text.JsonSerializer;
using Xunit;
using Xunit.Abstractions;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Models;
using ATAP.Utilities.ComputerInventory.Extensions;
using System.Collections;
//using ServiceStack.Text.EnumMemberSerializer;

namespace ATAP.Utilities.ComputerInventory.Models.UnitTests
{
  public class Fixture
  {
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
      computerHardware = new ComputerHardware(new CPU[1] { new CPU(CPUMaker.Intel) }, MainBoard, new VideoCard[1] { videoCard });
      JsConfig.TextCase = TextCase.PascalCase;
      JsConfig.TreatEnumAsInteger = true;
      JsConfig.ExcludeDefaultValues = false;
      //    new EnumSerializerConfigurator()
      //.WithAssemblies(AppDomain.CurrentDomain.GetAssemblies())
      //.WithNamespaceFilter(ns => ns.StartsWith("ATAP"))
      //.Configure();
    }

    #region (fields) one example of computer hardware 
    readonly MainBoard mainBoard;
    readonly CPU cPU;
    readonly CPU[] cPUs;
    readonly VideoCardDiscriminatingCharacteristics videoCardDiscriminatingCharacteristics;

    readonly VideoCard videoCard;
    readonly VideoCard[] videoCards;
    readonly VideoCardSensorData videoCardSensorData;
    readonly ComputerHardware computerHardware;
    #endregion

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

  public class ComputerInventoryModelsUnitTests001 : IClassFixture<Fixture>
  {

    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventoryModelsUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }

    void HandleTimer(object source, ElapsedEventArgs e)
    {
      Fixture.computerProcesses.Kill(Fixture.pidUnderTest);
    }

    [Theory]
    [InlineData("{\"ComputerHardware\":{\"Computer\":{\"MainboardEnabled\":true,\"CPUEnabled\":true,\"RAMEnabled\":false,\"GPUEnabled\":true,\"FanControllerEnabled\":true,\"HDDEnabled\":false,\"Hardware\":[]},\"CPUs\":[{\"Maker\":\"Intel\"}],\"MainBoard\":{\"Maker\":\"ASUS\",\"Socket\":\"ToDo:makeSocketanEnum\"},\"VideoCards\":[{\"BIOSVersion\":\"ToDo:readfromcard\",\"CoreClock\":-1.0,\"CoreVoltage\":-1.0,\"DeviceID\":\"ToDo:readfromcard\",\"IsStrapped\":false,\"MemClock\":-1.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":-1.0,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardDiscriminatingCharacteristics\":{\"CardName\":\"GTX 980 TI\",\"GPUMaker\":\"NVIDEA\",\"VideoCardMaker\":\"ASUS\",\"VideoMemoryMaker\":\"Samsung\",\"VideoMemorySize\":6144}}],\"IsMainboardEnabled\":true,\"IsCPUsEnabled\":true,\"IsVideoCardsEnabled\":true,\"IsFanControllerEnabled\":true,\"MainboardEnabled\":false,\"CPUEnabled\":false,\"RAMEnabled\":false,\"GPUEnabled\":false,\"FanControllerEnabled\":false,\"HDDEnabled\":false,\"Hardware\":[]},\"ComputerSoftware\":{\"ComputerSoftwareDrivers\":[{\"Name\":\"genericvideo\",\"Version\":\"1.0\"},{\"Name\":\"AMDVideoDriver\",\"Version\":\"1.0\"},{\"Name\":\"NVideaVideoDriver\",\"Version\":\"1.0\"}],\"ComputerSoftwarePrograms\":[{\"ProcessName\":\"EthDCRMiner\",\"ProcessPath\":\"C:\\\\\",\"ProcessStartPath\":\"C:\\\\\",\"Version\":\"10.2\",\"HasConfigurationSettings\":false,\"ConfigurationSettings\":null,\"ConfigFilePath\":null,\"HasLogFiles\":false,\"LogFileFolder\":null,\"LogFileFnPattern\":null,\"HasAPI\":false,\"HasSTDOut\":false,\"HasERROut\":false}]},\"ComputerProcesses\":{}}")]
    internal void ComputerInventorySerializeToJSON(string _testdatainput)
    {
      string str;
      ATAP.Utilities.ComputerInventory.Models.ComputerInventory computerInventory;
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
      str = SerializeToString(computerSoftwareProgram);
      List<ComputerSoftwareProgram> computerSoftwarePrograms = new List<ComputerSoftwareProgram> {
            computerSoftwareProgram
            };
      str = JsonSerializer.SerializeToString(computerSoftwarePrograms);
      List<ComputerSoftwareDriver> computerSoftwareDrivers = new List<ComputerSoftwareDriver> {
            new ComputerSoftwareDriver("genericvideo",
                                       "1.0"),
                new ComputerSoftwareDriver("AMDVideoDriver",
                                           "1.0"),
                new
                ComputerSoftwareDriver("NVideaVideoDriver",
                                       "1.0")
            };
      str = SerializeToString(computerSoftwareDrivers);
      // OperatingSystem os = Environment.OSVersion;
      //str = SerializeToString(os);
      computerSoftware = new ComputerSoftware(computerSoftwareDrivers, computerSoftwarePrograms);
      str = SerializeToString(computerSoftware);
      computerProcesses = new ComputerProcesses();
      str = SerializeToString(computerProcesses);
      computerInventory = new ATAP.Utilities.ComputerInventory.Models.ComputerInventory(Fixture.ComputerHardware, computerSoftware, computerProcesses);
      str = SerializeToString(computerInventory);
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
      Fixture.computerProcesses = new ComputerProcesses();
      // stop the program in 1/2 of the specified test run time (specifiedTestRunTime is in seconds, timers are in milliseconds)
      Timer aTimer = new Timer(specifiedTestRunTime * 500);
      aTimer.Elapsed += new ElapsedEventHandler(HandleTimer);
      TimeInterval ti = new TimeInterval(System.DateTime.Now);
      Fixture.pidUnderTest = Fixture.computerProcesses.Start(powerShell,
                                                               new object[2] {
            "-Command",
                $"&{{start-sleep -s {_testdatainput}; exit}}"
      });
      aTimer.Start();
      // wait for the program to stop. The event handler should stop it.
      var p = Fixture.computerProcesses.ComputerProcessDictionary[Fixture.pidUnderTest];
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
      Fixture.computerProcesses = new ComputerProcesses();
      TimeInterval ti = new TimeInterval(System.DateTime.Now);
      Fixture.pidUnderTest = Fixture.computerProcesses.Start(powerShell,
                                                               new object[2] {
            "-Command",
                $"&{{start-sleep -s {_testdatainput}; exit}}"
      });
      // wait for the program to stop
      var p = Fixture.computerProcesses.ComputerProcessDictionary[Fixture.pidUnderTest];
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


  }

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class CPUTestData
  {
    public CPU CPU;
    public string SerializedCPU;

    public CPUTestData()
    {
    }

    public CPUTestData(CPU cPU, string serializedCPU)
    {
      CPU = cPU ?? throw new ArgumentNullException(nameof(cPU));
      SerializedCPU = serializedCPU ?? throw new ArgumentNullException(nameof(serializedCPU));
    }
  }

  public class CPUTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> CPUTestData()
    {
      yield return new CPUTestData[] { new CPUTestData { CPU = new CPU(CPUMaker.Generic), SerializedCPU = "{\"Maker\":0}" } };
      yield return new CPUTestData[] { new CPUTestData { CPU = new CPU(CPUMaker.Intel), SerializedCPU = "{\"Maker\":1}" } };
      yield return new CPUTestData[] { new CPUTestData { CPU = new CPU(CPUMaker.AMD), SerializedCPU = "{\"Maker\":2}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return CPUTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }


  public class CPUArrayTestData
  {
    public CPU[] CPUArray;
    public string SerializedCPUArray;

    public CPUArrayTestData()
    {
    }

    public CPUArrayTestData(CPU[] cPUArray, string serializedCPUArray)
    {
      CPUArray = cPUArray ?? throw new ArgumentNullException(nameof(cPUArray));
      SerializedCPUArray = serializedCPUArray ?? throw new ArgumentNullException(nameof(serializedCPUArray));
    }
  }

  public class CPUArrayTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> CPUArrayTestData()
    {
      yield return new CPUArrayTestData[] { new CPUArrayTestData { CPUArray = new CPU[] { new CPU(CPUMaker.Generic) }, SerializedCPUArray = "[{\"Maker\":0}]" } };
      yield return new CPUArrayTestData[] { new CPUArrayTestData { CPUArray = new CPU[] { new CPU(CPUMaker.Intel) }, SerializedCPUArray = "[{\"Maker\":1}]" } };
      yield return new CPUArrayTestData[] { new CPUArrayTestData { CPUArray = new CPU[] { new CPU(CPUMaker.AMD) }, SerializedCPUArray = "[{\"Maker\":2}]" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return CPUArrayTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  public class PowerConsumptionTestData
  {
    public PowerConsumption PowerConsumption;
    public string SerializedPowerConsumption;

    public PowerConsumptionTestData() { }

    public PowerConsumptionTestData(PowerConsumption PowerConsumption, string serializedPowerConsumption)
    {
      PowerConsumption = PowerConsumption ?? throw new ArgumentNullException(nameof(PowerConsumption));
      SerializedPowerConsumption = serializedPowerConsumption ?? throw new ArgumentNullException(nameof(serializedPowerConsumption));
    }
  }

  public class PowerConsumptionTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> PowerConsumptionTestData()
    {
      yield return new PowerConsumptionTestData[] { new PowerConsumptionTestData { PowerConsumption = new PowerConsumption(10.0, new TimeSpan(0, 0, 1)), SerializedPowerConsumption = "{\"Period\":\"00:00:01\",\"Watts\":1000.0}" } };
      yield return new PowerConsumptionTestData[] { new PowerConsumptionTestData { PowerConsumption = new PowerConsumption(1.0, new TimeSpan(0, 1, 0)), SerializedPowerConsumption = "{\"Period\":00:01:00,\"Watts\":10.0}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return PowerConsumptionTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }


  public class TempAndFanTestData
  {
    public TempAndFan TempAndFan;
    public string SerializedTempAndFan;

    public TempAndFanTestData() { }

    public TempAndFanTestData(TempAndFan tempAndFan, string serializedTempAndFan)
    {
      TempAndFan = tempAndFan ?? throw new ArgumentNullException(nameof(tempAndFan));
      SerializedTempAndFan = serializedTempAndFan ?? throw new ArgumentNullException(nameof(serializedTempAndFan));
    }
  }


  public class TempAndFanArrayTestData
  {
    public TempAndFan[] TempAndFanArray;
    public string SerializedTempAndFanArray;

    public TempAndFanArrayTestData()
    {
    }

    public TempAndFanArrayTestData(TempAndFan[] tempAndFanArray, string serializedTempAndFanArray)
    {
      TempAndFanArray = tempAndFanArray ?? throw new ArgumentNullException(nameof(tempAndFanArray));
      SerializedTempAndFanArray = serializedTempAndFanArray ?? throw new ArgumentNullException(nameof(serializedTempAndFanArray));
    }
  }

  public class TempAndFanTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TempAndFanTestData()
    {
      yield return new TempAndFanTestData[] { new TempAndFanTestData { TempAndFan = new TempAndFan { Temp = 50, FanPct = 95.5 }, SerializedTempAndFan = "{\"Temp\":50,\"FanPct\":95.5}" } };
      yield return new TempAndFanTestData[] { new TempAndFanTestData { TempAndFan = new TempAndFan { Temp = 0.0, FanPct = 100.0 }, SerializedTempAndFan = "{\"Temp\":0,\"FanPct\":100}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return TempAndFanTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  public class TempAndFanArrayTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TempAndFanArrayTestData()
    {
      yield return new TempAndFanArrayTestData[] { new TempAndFanArrayTestData { TempAndFanArray = new TempAndFan[] { new TempAndFan { Temp = 50, FanPct = 100 } }, SerializedTempAndFanArray = "[{\"Temp\":50,\"FanPct\":100}]" }, };
      yield return new TempAndFanArrayTestData[] { new TempAndFanArrayTestData { TempAndFanArray = new TempAndFan[] { new TempAndFan { Temp = 50.1, FanPct = 100.1 } }, SerializedTempAndFanArray = "[{\"Temp\":50.1,\"FanPct\":100.1}]" }, };
    }
    public IEnumerator<object[]> GetEnumerator() { return TempAndFanArrayTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

  public class ComputerInventoryModelsHardwareUnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventoryModelsHardwareUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;

      // Explicity Configure ServiceStack Enmeration serialization
      // new EnumSerializerConfigurator()
      //.WithAssemblies(AppDomain.CurrentDomain.GetAssemblies())
      //.WithNamespaceFilter(ns => ns.StartsWith("ATAP"))
      //.Configure();
    }

    [Theory]
    [MemberData(nameof(CPUTestDataGenerator.CPUTestData), MemberType = typeof(CPUTestDataGenerator))]
    public void CPUDeserializeFromJSON(CPUTestData inCPUTestData)
    {
      CPU cPU = DeserializeFromString<CPU>(inCPUTestData.SerializedCPU);
      TestOutput.WriteLine(cPU.Maker.ToString());
      DeserializeFromString<CPU>(inCPUTestData.SerializedCPU).Should().Be(inCPUTestData.CPU);
    }

    [Theory]
    [MemberData(nameof(CPUTestDataGenerator.CPUTestData), MemberType = typeof(CPUTestDataGenerator))]
    public void CPUSerializeToJSON(CPUTestData inCPUTestData)
    {
      string str = SerializeToString(inCPUTestData.CPU);
      TestOutput.WriteLine(str);
      SerializeToString(inCPUTestData.CPU).Should().Be(inCPUTestData.SerializedCPU);
    }

    [Theory]
    [MemberData(nameof(CPUArrayTestDataGenerator.CPUArrayTestData), MemberType = typeof(CPUArrayTestDataGenerator))]
    public void CPUArrayDeserializeFromJSON(CPUArrayTestData inCPUArrayTestData)
    {
      CPU[] cPUArray = DeserializeFromString<CPU[]>(inCPUArrayTestData.SerializedCPUArray);
      cPUArray.Should().BeEquivalentTo(inCPUArrayTestData.CPUArray);
    }

    [Theory]
    [MemberData(nameof(CPUArrayTestDataGenerator.CPUArrayTestData), MemberType = typeof(CPUArrayTestDataGenerator))]
    public void CPUArraySerializeToJSON(CPUArrayTestData inCPUArrayTestData)
    {
      string str = SerializeToString(inCPUArrayTestData.CPUArray);
      str.Should().Be(inCPUArrayTestData.SerializedCPUArray);
    }

    [Theory]
    [MemberData(nameof(PowerConsumptionTestDataGenerator.PowerConsumptionTestData), MemberType = typeof(PowerConsumptionTestDataGenerator))]
    public void PowerConsumptionDeserializeFromJSON(PowerConsumptionTestData inPowerConsumptionTestData)
    {
      PowerConsumption powerConsumption = DeserializeFromString<PowerConsumption>(inPowerConsumptionTestData.SerializedPowerConsumption);
      powerConsumption.Should().Be(inPowerConsumptionTestData.PowerConsumption);
    }

    [Theory]
    [MemberData(nameof(PowerConsumptionTestDataGenerator.PowerConsumptionTestData), MemberType = typeof(PowerConsumptionTestDataGenerator))]
    public void PowerConsumptionSerializeToJSON(PowerConsumptionTestData inPowerConsumptionTestData)
    {
      string str = SerializeToString(inPowerConsumptionTestData.SerializedPowerConsumption);
      str.Should().Be(inPowerConsumptionTestData.SerializedPowerConsumption);
    }

    [Theory]
    [MemberData(nameof(TempAndFanTestDataGenerator.TempAndFanTestData), MemberType = typeof(TempAndFanTestDataGenerator))]
    public void TempAndFanDeserializeFromJSON(TempAndFanTestData inTempAndFanTestData)
    {
      var tempAndFan = DeserializeFromString<TempAndFan>(inTempAndFanTestData.SerializedTempAndFan);
      tempAndFan.Should().BeEquivalentTo(inTempAndFanTestData.TempAndFan);
    }

    [Theory]
    [MemberData(nameof(TempAndFanTestDataGenerator.TempAndFanTestData), MemberType = typeof(TempAndFanTestDataGenerator))]
    public void TempAndFanSerializeToJSON(TempAndFanTestData inTempAndFanTestData)
    {
      var serializedTempAndFan = SerializeToString<TempAndFan>(inTempAndFanTestData.TempAndFan);
      serializedTempAndFan.Should().Be(inTempAndFanTestData.SerializedTempAndFan);
    }

    [Theory]
    [MemberData(nameof(TempAndFanArrayTestDataGenerator.TempAndFanArrayTestData), MemberType = typeof(TempAndFanArrayTestDataGenerator))]
    public void TempAndFanArrayDeserializeFromJSON(TempAndFanArrayTestData inTempAndFanArrayTestData)
    {
      var tempAndFanArray = DeserializeFromString<TempAndFan[]>(inTempAndFanArrayTestData.SerializedTempAndFanArray);
      tempAndFanArray.Should().BeEquivalentTo(inTempAndFanArrayTestData.TempAndFanArray);
    }

    [Theory]
    [MemberData(nameof(TempAndFanArrayTestDataGenerator.TempAndFanArrayTestData), MemberType = typeof(TempAndFanArrayTestDataGenerator))]
    public void TempAndFanArraySerializeToJSON(TempAndFanArrayTestData inTempAndFanArrayTestData)
    {
      using (JsConfig.With(new Config { TextCase = TextCase.PascalCase }))
      {
        var serializedTempAndFanArray = SerializeToString<TempAndFan[]>(inTempAndFanArrayTestData.TempAndFanArray);
        serializedTempAndFanArray.Should().Be(inTempAndFanArrayTestData.SerializedTempAndFanArray);
      }
    }

    [Theory]
    [InlineData("{\"BIOSVersion\":\"100.00001.02320.00\",\"CardName\":\"GTX 980 TI\",\"CoreClock\":1140.0,\"CoreVoltage\":11.13,\"DeviceID\":\"10DE 17C8 - 3842\",\"IsStrapped\":false,\"MemClock\":1753.0,\"PowerConsumption\":{\"Period\":\"00:01:00\",\"Watts\":1000.0},\"PowerLimit\":0.8,\"TempAndFan\":{\"Temp\":60.0,\"FanPct\":50.0},\"VideoCardMaker\":\"ASUS\",\"GPUMaker\":\"NVIDEA\"}")]
    internal void VideoCardDeserializeFromJSON(string _testdatainput)
    {
      VideoCard vc = DeserializeFromString<VideoCard>(_testdatainput);
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
      string str = SerializeToString(videoCard);
      str.Should()
          .NotBeNull();
      str.Should()
          .Be(_testdatainput);
    }
    [Fact]
    public void MainBoardDeserializeFromJSON()
    {
      MainBoard mainBoard = DeserializeFromString<MainBoard>(SerializeToString(Fixture.MainBoard));
      mainBoard.Should()
          .Be(Fixture.MainBoard);
    }


  }
}
