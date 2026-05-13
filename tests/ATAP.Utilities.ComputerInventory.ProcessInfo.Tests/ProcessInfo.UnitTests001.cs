using System;
using System.Collections.Generic;
using System.Linq;
using System.Timers;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;
using ServiceStack.Text;
using ATAP.Utilities.ComputerInventory;
using Itenso.TimePeriod;
using ATAP.Utilities.ComputerInventory.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.ComputerInventory.Software;
using Medallion.Shell;
using System.Threading.Tasks;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.ProcessInfo.UnitTests
{

  public class Fixture : DiFixture
  {
    public Fixture() : base()
    {
    }

    public ComputerProcesses ComputerProcesses { get; set; }
    public int PidUnderTest { get; set; }

  }

  public class ModelsProcessInfoUnitTests001 : IClassFixture<Fixture>
  {

    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ModelsProcessInfoUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }

    void HandleTimer(object source, ElapsedEventArgs e)
    {
      Fixture.ComputerProcesses.Kill(Fixture.PidUnderTest);
    }



    [Theory]
    [MemberData(nameof(ComputerProcessesStartStopTestDataGenerator.ComputerProcessesStartStopTestData), MemberType = typeof(ComputerProcessesStartStopTestDataGenerator))]
    public async void ComputerProcessesStartStopTest001(ComputerProcessesStartStopTestData TestData)
    {
      int specifiedTestRunTime = TestData.SpecifiedTestRunTime;
      ComputerSoftwareProgram computerSoftwareProgram = TestData.ComputerSoftwareProgram;
      object[] arguments = TestData.Arguments;
      Fixture.ComputerProcesses = new ComputerProcesses();
      // stop the program in 1/2 of the specified test run time (specifiedTestRunTime is in seconds, timers are in milliseconds)
      Timer aTimer = new Timer(specifiedTestRunTime * 500);
      aTimer.Elapsed += new ElapsedEventHandler(HandleTimer);
      TimeInterval ti = new TimeInterval(System.DateTime.Now);
      //ToDo turn this into a COD dictionary <int,Command>
      Fixture.PidUnderTest = Fixture.ComputerProcesses.Start(
        computerSoftwareProgram,
        //new Command(),
        arguments
        //new object[2] {
        //       "-Command",
        //           $"&{{start-sleep -s {TestData.SpecifiedTestRunTime}; exit}}"
        //}
        );
      aTimer.Start();
      // wait for the program to stop. The event handler should stop it.
      var p = Fixture.ComputerProcesses.ComputerProcessDictionary[Fixture.PidUnderTest];
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
    }
        /*
    [Theory]
    [InlineData("5")]
    public async void ComputerProcessesStartTest001(string _testdatainput)
    {
      int specifiedTestRunTime = int.Parse(_testdatainput);
      // ToDo: Need to create a ComputerSoftwareProgram for PowerShell as a builtin, and figure out how to get its path "the right way"
      ComputerSoftwareProgram powerShell = new ComputerSoftwareProgram(DefaultConfiguration.Production["PowerShell"],new Philote.Philote<IComputerSoftwareProgram>());
      DiFixture.ComputerProcesses = new ComputerProcesses();
      TimeInterval ti = new TimeInterval(System.DateTime.Now);
      DiFixture.pidUnderTest = DiFixture.ComputerProcesses.Start(powerShell,
                                                               new object[2] {
            "-Command",
                $"&{{start-sleep -s {_testdatainput}; exit}}"
      });
      // wait for the program to stop
      var p = DiFixture.ComputerProcesses.ComputerProcessDictionary[DiFixture.pidUnderTest];
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

    }
          */

    }
  }
}

