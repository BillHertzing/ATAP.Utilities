using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using System;
using ATAP.Utilities.ComputerInventory.Configuration.Software;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class ComputerProcessesStartStopTestData
  {
    public ComputerSoftwareProgram ComputerSoftwareProgram;
    public int SpecifiedTestRunTime;

    public ComputerProcessesStartStopTestData()
    {
    }

    public ComputerProcessesStartStopTestData(ComputerSoftwareProgram computerSoftwareProgram, int specifiedTestRunTime)
    {
      ComputerSoftwareProgram = computerSoftwareProgram ?? throw new ArgumentNullException(nameof(computerSoftwareProgram));
      SpecifiedTestRunTime = specifiedTestRunTime;
    }
  }

  public class ComputerProcessesStartStopTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> ComputerProcessesStartStopTestData()
    {
      yield return new ComputerProcessesStartStopTestData[] { new ComputerProcessesStartStopTestData {
        ComputerSoftwareProgram = new ComputerSoftwareProgram(),
        SpecifiedTestRunTime = 10 } };
    }
    public IEnumerator<object[]> GetEnumerator() { return ComputerProcessesStartStopTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
