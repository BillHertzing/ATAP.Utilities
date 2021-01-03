using System;
using System.Collections.Generic;
using System.Linq;
using System.Timers;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using ServiceStack.Text;
using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.Testing;
using Itenso.TimePeriod;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{

  public partial class ComputerInventoryUnitTests001 : IClassFixture<ComputerInventoryFixture>
  {
    /*
  [SkipBecauseNotWorkingTheory]
  [MemberData(nameof(ComputerInventoryTestDataGenerator.TestData), MemberType = typeof(ComputerInventoryTestDataGenerator))]

  internal void ComputerInventorySerializeToJSON(ComputerInventoryTestData inComputerInventoryTestData)
  {
    DiFixture.Serializer.Serialize(inComputerInventoryTestData.ComputerInventory).Should().Be(inComputerInventoryTestData.SerializedComputerInventory);

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
    str = DiFixture.Serializer.Serialize(computerSoftwareProgram);
    List<IComputerSoftwareProgram> computerSoftwarePrograms = new List<IComputerSoftwareProgram> {
          computerSoftwareProgram
          };
    str = DiFixture.Serializer.Serialize(computerSoftwarePrograms);
    List<IComputerSoftwareDriver> computerSoftwareDrivers = new List<IComputerSoftwareDriver> {
          new ComputerSoftwareDriver("genericvideo",
                                     "1.0"),
              new ComputerSoftwareDriver("AMDVideoDriver",
                                         "1.0"),
              new
              ComputerSoftwareDriver("NVideaVideoDriver",
                                     "1.0")
          };
    str = DiFixture.Serializer.Serialize(computerSoftwareDrivers);
    // OperatingSystem os = Environment.OSVersion;
    //str = DiFixture.Serializer.Serialize(os);
    computerSoftware = new ComputerSoftware(computerSoftwareDrivers, computerSoftwarePrograms);
    str = DiFixture.Serializer.Serialize(computerSoftware);
    computerProcesses = new ComputerProcesses();
    str = DiFixture.Serializer.Serialize(computerProcesses);
    computerInventory = new ATAP.Utilities.ComputerInventory.Models.ComputerInventory(DiFixture.ComputerHardware, computerSoftware, computerProcesses);
    str = DiFixture.Serializer.Serialize(computerInventory);
    str.Should()
        .NotBeNull();
    str.Should()
        .Be(_testdatainput);

  }
      */
  }

}

/*  public class ComputerInventoryModelsHardwareUnitTests001 : IClassFixture<DiFixture>
  {

    protected DiFixture DiFixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventoryModelsHardwareUnitTests001(ITestOutputHelper testOutput, DiFixture diFixture)
    {
      DiFixture = diFixture;
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
  DiFixture.computerProcesses = new ComputerProcesses();
  // stop the program in 1/2 of the specified test run time (specifiedTestRunTime is in seconds, timers are in milliseconds)
  Timer aTimer = new Timer(specifiedTestRunTime * 500);
  aTimer.Elapsed += new ElapsedEventHandler(HandleTimer);
  TimeInterval ti = new TimeInterval(System.DateTime.Now);
  DiFixture.pidUnderTest = DiFixture.computerProcesses.Start(powerShell,
                                                           new object[2] {
            "-Command",
                $"&{{start-sleep -s {_testdatainput}; exit}}"
  });
  aTimer.Start();
  // wait for the program to stop. The event handler should stop it.
  var p = DiFixture.computerProcesses.ComputerProcessDictionary[DiFixture.pidUnderTest];
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
  DiFixture.computerProcesses = new ComputerProcesses();
  TimeInterval ti = new TimeInterval(System.DateTime.Now);
  DiFixture.pidUnderTest = DiFixture.computerProcesses.Start(powerShell,
                                                           new object[2] {
            "-Command",
                $"&{{start-sleep -s {_testdatainput}; exit}}"
  });
  // wait for the program to stop
  var p = DiFixture.computerProcesses.ComputerProcessDictionary[DiFixture.pidUnderTest];
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
