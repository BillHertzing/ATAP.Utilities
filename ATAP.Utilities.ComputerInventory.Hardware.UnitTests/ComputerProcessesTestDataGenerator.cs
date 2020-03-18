using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using System;
using ATAP.Utilities.ComputerInventory.Configuration.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Configuration.Software;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{


  public class ComputerProcessesTestData
  {
    public ComputerProcesses ComputerProcesses;
    public string SerializedComputerProcesses;

    public ComputerProcessesTestData()
    {
    }

    public ComputerProcessesTestData(ComputerProcesses computerProcesses, string serializedComputerProcesses)
    {
      ComputerProcesses = computerProcesses ?? throw new ArgumentNullException(nameof(computerProcesses));
      SerializedComputerProcesses = serializedComputerProcesses ?? throw new ArgumentNullException(nameof(serializedComputerProcesses));
    }
  }
  public class ComputerProcessesTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> ComputerProcessesTestData()
    {
      yield return new ComputerProcessesTestData[] { new ComputerProcessesTestData {
        ComputerProcesses = new ComputerProcesses(),
        SerializedComputerProcesses = "testnotwritten" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return ComputerProcessesTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }


}

