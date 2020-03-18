using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Enumerations;
using System;

namespace ATAP.Utilities.ComputerInventory.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class CPUSocketTestData
  {
    public CPUSocket CPUSocket;
    public string SerializedCPUSocket;

    public CPUSocketTestData()
    {
    }

    public CPUSocketTestData(CPUSocket cPUSocket, string serializedCPUSocket)
    {
      CPUSocket = cPUSocket;
      SerializedCPUSocket = serializedCPUSocket ?? throw new ArgumentNullException(nameof(serializedCPUSocket));
    }
  }

  public class CPUSocketTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> CPUSocketTestData()
    {
      yield return new CPUSocketTestData[] { new CPUSocketTestData { CPUSocket = CPUSocket.Generic, SerializedCPUSocket = "0" } };
      yield return new CPUSocketTestData[] { new CPUSocketTestData { CPUSocket = CPUSocket.LGA1136, SerializedCPUSocket = "1" } };
      yield return new CPUSocketTestData[] { new CPUSocketTestData { CPUSocket = CPUSocket.LGA1155, SerializedCPUSocket = "2" } };
      yield return new CPUSocketTestData[] { new CPUSocketTestData { CPUSocket = CPUSocket.LGA1156, SerializedCPUSocket = "3" } };
      yield return new CPUSocketTestData[] { new CPUSocketTestData { CPUSocket = CPUSocket.LGA775, SerializedCPUSocket = "4" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return CPUSocketTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
