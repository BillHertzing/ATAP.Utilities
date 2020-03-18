using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using ATAP.Utilities.ComputerInventory.Software;

namespace ATAP.Utilities.ComputerInventory.ProcessInfo.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class ComputerProcessesStartStopTestData
  {
    public ComputerSoftwareProgram ComputerSoftwareProgram { get; set; }
    public int SpecifiedTestRunTime { get; set; }
    public object[] Arguments { get; set; }

    public ComputerProcessesStartStopTestData(ComputerSoftwareProgram computerSoftwareProgram, object[] arguments, int specifiedTestRunTime)
    {
      ComputerSoftwareProgram = computerSoftwareProgram ?? throw new ArgumentNullException(nameof(computerSoftwareProgram));
      Arguments = arguments ?? throw new ArgumentNullException(nameof(arguments));
      SpecifiedTestRunTime = specifiedTestRunTime;
    }

    public ComputerProcessesStartStopTestData()
    {
    }
  }

  public class ComputerProcessesStartStopTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> ComputerProcessesStartStopTestData()
    {
      yield return new ComputerProcessesStartStopTestData[] { new ComputerProcessesStartStopTestData() {
        ComputerSoftwareProgram = new ComputerSoftwareProgram(DefaultConfiguration.Production["PowerShell"],new Philote.Philote<IComputerSoftwareProgram>()),
        // ToDo how to pass a placeholder/substitution in the arguments object Arguments = new object[2] {"-Command",$"&{{start-sleep -s {TestData.SpecifiedTestRunTime}; exit}}" },
        Arguments = new object[2] {"-Command",$"&{{start-sleep -s 10; exit}}" },
        SpecifiedTestRunTime = 10 } };
    }
    public IEnumerator<object[]> GetEnumerator() { return ComputerProcessesStartStopTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
