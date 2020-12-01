using System.Collections.Generic;
using System.Collections;
using  ATAP.Utilities.ComputerInventory.Hardware;
using System;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class CPUSocketTestData : TestData<CPUSocket>
  {
    public CPUSocketTestData(CPUSocket objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class CPUSocketTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new CPUSocketTestData[] { new CPUSocketTestData(CPUSocket.Generic, "0") };
      yield return new CPUSocketTestData[] { new CPUSocketTestData(CPUSocket.LGA1136, "1") };
      yield return new CPUSocketTestData[] { new CPUSocketTestData(CPUSocket.LGA1155, "2") };
      yield return new CPUSocketTestData[] { new CPUSocketTestData(CPUSocket.LGA1156, "3") };
      yield return new CPUSocketTestData[] { new CPUSocketTestData(CPUSocket.LGA775, "4") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
