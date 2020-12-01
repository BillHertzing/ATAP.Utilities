using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{
  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class CPUEnumerableTestData : TestDataEn<ICPU>
  {
    public CPUEnumerableTestData(IEnumerable<TestData<ICPU>> e) : base(e)
    {
    }
  }
  public class CPUEnumerableTestDataGenerator : IEnumerable<object[]>
  {
    public static CPU CPUStaticDefault = new CPU();
    public static TestData<ICPU> CPUTestDataStaticDefault = new TestData<ICPU>(CPUStaticDefault, "{\"CPUSignil\":\"stuff\"");
    public static IEnumerable<object[]> TestData()
    {
      // An empty list
      yield return new CPUEnumerableTestData[] { new CPUEnumerableTestData(new List<TestData<ICPU>>()) };
      // a list with just the default instance of the type
      yield return new CPUEnumerableTestData[] {
        new CPUEnumerableTestData(
          new List<TestData<ICPU>>() {
            new TestData<ICPU>(new CPU(), "{\"CPUSignil\":{\"CPUMaker\":0,\"CPUSocket\":0,\"NumberOfPhysicalCores\":0,\"CoreClockNominal\":\"0 Hz\",\"CoreVoltageNominal\":\"0 Vdc\"},\"Philote\":null}")
          })
      };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
