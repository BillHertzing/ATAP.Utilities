using System;
using System.Collections.Generic;
using System.Linq;
using System.Timers;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using ServiceStack.Text;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Extensions;
using ATAP.Utilities.ComputerInventory.Configuration;
using Itenso.TimePeriod;
using ATAP.Utilities.ComputerInventory.Configuration.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using ATAP.Utilities.ComputerInventory.Configuration.Software;
using ATAP.Utilities.ComputerInventory.Interfaces.Software;

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{
  public class Fixture
  {
    public ComputerProcesses computerProcesses;
    public int pidUnderTest;


    public Fixture()
    {
      JsConfig.TextCase = TextCase.PascalCase;
      JsConfig.TreatEnumAsInteger = true;
      JsConfig.ExcludeDefaultValues = false;
      //    new EnumSerializerConfigurator()
      //.WithAssemblies(AppDomain.CurrentDomain.GetAssemblies())
      //.WithNamespaceFilter(ns => ns.StartsWith("ATAP"))
      //.Configure();
    }

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

    [Theory]
    [MemberData(nameof(ComputerInventoryTestDataGenerator.ComputerInventoryTestData), MemberType = typeof(ComputerInventoryTestDataGenerator))]

    internal void ComputerInventorySerializeToJSON(ComputerInventoryTestData inComputerInventoryTestData)
    {
      JsonSerializer.SerializeToString(inComputerInventoryTestData.ComputerInventory).Should().Be(inComputerInventoryTestData.SerializedComputerInventory);
      /*
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
      str = JsonSerializer.SerializeToString(computerSoftwareProgram);
      List<IComputerSoftwareProgram> computerSoftwarePrograms = new List<IComputerSoftwareProgram> {
            computerSoftwareProgram
            };
      str = JsonSerializer.SerializeToString(computerSoftwarePrograms);
      List<IComputerSoftwareDriver> computerSoftwareDrivers = new List<IComputerSoftwareDriver> {
            new ComputerSoftwareDriver("genericvideo",
                                       "1.0"),
                new ComputerSoftwareDriver("AMDVideoDriver",
                                           "1.0"),
                new
                ComputerSoftwareDriver("NVideaVideoDriver",
                                       "1.0")
            };
      str = JsonSerializer.SerializeToString(computerSoftwareDrivers);
      // OperatingSystem os = Environment.OSVersion;
      //str = JsonSerializer.SerializeToString(os);
      computerSoftware = new ComputerSoftware(computerSoftwareDrivers, computerSoftwarePrograms);
      str = JsonSerializer.SerializeToString(computerSoftware);
      computerProcesses = new ComputerProcesses();
      str = JsonSerializer.SerializeToString(computerProcesses);
      computerInventory = new ATAP.Utilities.ComputerInventory.Models.ComputerInventory(Fixture.ComputerHardware, computerSoftware, computerProcesses);
      str = JsonSerializer.SerializeToString(computerInventory);
      str.Should()
          .NotBeNull();
      str.Should()
          .Be(_testdatainput);
      */
    }

  }

}

/*  public class ComputerInventoryModelsHardwareUnitTests001 : IClassFixture<Fixture>
  {

    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventoryModelsHardwareUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }


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
  await p.Command.Task;
  ti.ExpandTo(System.DateTime.Now);
  // Dispose of the timer
  aTimer.Dispose();
  var processResult = p.Command.Task.Result;
  p.Command.Result.ExitCode.Should()
      .Be(-1);
  p.Command.Result.Success.Should()
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
  await p.Command.Task;
  ti.ExpandTo(System.DateTime.Now);
  var processResult = p.Command.Task.Result;
  p.Command.Result.ExitCode.Should()
      .Be(0);
  p.Command.Result.Success.Should()
      .Be(true);
  ti.Duration.Should()
      .BeCloseTo(new TimeSpan(0, 0, specifiedTestRunTime), 1000);
}


  }

*/
