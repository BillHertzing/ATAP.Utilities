using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{


  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class CPUMakerTestData : TestData<CPUMaker>
  {
    public CPUMakerTestData(CPUMaker objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class CPUMakerTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new CPUMakerTestData[] { new CPUMakerTestData(CPUMaker.Generic, "0") };
      yield return new CPUMakerTestData[] { new CPUMakerTestData(CPUMaker.Intel, "1") };
      yield return new CPUMakerTestData[] { new CPUMakerTestData(CPUMaker.AMD, "2") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
