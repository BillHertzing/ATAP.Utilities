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
using Medallion.Shell;
using System.Threading.Tasks;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{

  public class ProcessInfofixture : Fixture
  {
    public ProcessInfofixture() :base ()
    {
    }

    public ComputerProcesses computerProcesses { get; set; }
    public int pidUnderTest { get; set; }

  }

  public class ModelsProcessInfoUnitTests001 : IClassFixture<ProcessInfofixture>
  {

    protected ProcessInfofixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ModelsProcessInfoUnitTests001(ITestOutputHelper testOutput, ProcessInfofixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }

    void HandleTimer(object source, ElapsedEventArgs e)
    {
      Fixture.computerProcesses.Kill(Fixture.pidUnderTest);
    }



    [Theory]
    [MemberData(nameof(ComputerProcessesStartStopTestDataGenerator.ComputerProcessesStartStopTestData), MemberType = typeof(ComputerProcessesStartStopTestDataGenerator))]
    public async void ComputerProcessesStartStopTest001(ComputerProcessesStartStopTestData inComputerProcessesStartStopTestData)
    {
      int specifiedTestRunTime = inComputerProcessesStartStopTestData.SpecifiedTestRunTime;
      ComputerSoftwareProgram powerShell = inComputerProcessesStartStopTestData.ComputerSoftwareProgram;
      Fixture.computerProcesses = new ComputerProcesses();
      // stop the program in 1/2 of the specified test run time (specifiedTestRunTime is in seconds, timers are in milliseconds)
      Timer aTimer = new Timer(specifiedTestRunTime * 500);
      aTimer.Elapsed += new ElapsedEventHandler(HandleTimer);
      TimeInterval ti = new TimeInterval(System.DateTime.Now);
      Fixture.pidUnderTest = Fixture.computerProcesses.Start(
        powerShell,
        //new Command(),
        new object[2] {
            "-Command",
                $"&{{start-sleep -s {inComputerProcessesStartStopTestData.SpecifiedTestRunTime}; exit}}"
      });
      aTimer.Start();
      // wait for the program to stop. The event handler should stop it.
      var p = Fixture.computerProcesses.ComputerProcessDictionary[Fixture.pidUnderTest];
      await Task.Delay(10); //ToDo Fix this test
      /*
      await p.Command.Task;
      ti.ExpandTo(System.DateTime.Now);
      // Dispose of the timer
      aTimer.Dispose();
      var processResult = p.Command.Task.Result;
      p.Command.Result.ExitCode.Should().Be(-1);
      p.Command.Result.Success.Should().Be(false);
      ti.Duration.Should().BeCloseTo(new TimeSpan(0, 0, specifiedTestRunTime / 2), 1000);
      */
    }

    [Theory]
    [InlineData("5")]
    public async void ComputerProcessesStartTest001(string _testdatainput)
    {
      int specifiedTestRunTime = int.Parse(_testdatainput);
      // ToDo: Need to create a ComputerSoftwareProgram for PowerShell as a builtin, and figure out how to get its path "the right way" 
      ComputerSoftwareProgram powerShell = DefaultConfiguration.PowerShell;
      Fixture.computerProcesses = new ComputerProcesses();
      TimeInterval ti = new TimeInterval(System.DateTime.Now);
      Fixture.pidUnderTest = Fixture.computerProcesses.Start(powerShell,
                                                               new object[2] {
            "-Command",
                $"&{{start-sleep -s {_testdatainput}; exit}}"
      });
      // wait for the program to stop
      var p = Fixture.computerProcesses.ComputerProcessDictionary[Fixture.pidUnderTest];
      await Task.Delay(10); //ToDo Fix this test
      /*
      await p.Command.Task;
      ti.ExpandTo(System.DateTime.Now);
      var processResult = p.Command.Task.Result;
      p.Command.Result.ExitCode.Should()
          .Be(0);
      p.Command.Result.Success.Should()
          .Be(true);
      ti.Duration.Should()
          .BeCloseTo(new TimeSpan(0, 0, specifiedTestRunTime), 1000);
          */
    }


  }

}
