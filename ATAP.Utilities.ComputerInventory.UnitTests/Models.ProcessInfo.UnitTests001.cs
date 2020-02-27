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

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{
  

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
      Fixture.computerProcesses.Kill(Fixture.pidUnderTest);
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

}
