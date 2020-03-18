using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using ATAP.Utilities.ComputerInventory.ProcessInfo;
using ATAP.Utilities.ComputerInventory.Software;

namespace ATAP.Utilities.ComputerInventory.Software.UnitTests

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

