using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.Tests
{
  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class CPUEnumerableTestData : TestDataEn<ICPU>
  {
    public CPUEnumerableTestData(IEnumerable<SerializedTestData<ICPU>> e) : base(e)
    {
    }
  }
  public class CPUEnumerableTestDataGenerator : IEnumerable<object[]>
  {
    public static CPU CPUStaticDefault = new CPU();
    public static SerializedTestData<ICPU> CPUTestDataStaticDefault = new SerializedTestData<ICPU>(CPUStaticDefault, "{\"CPUSignil\":\"stuff\"");
    public static IEnumerable<object[]> TestData()
    {
      // An empty list
      yield return new CPUEnumerableTestData[] { new CPUEnumerableTestData(new List<SerializedTestData<ICPU>>()) };
      // a list with just the default instance of the type
      yield return new CPUEnumerableTestData[] {
        new CPUEnumerableTestData(
          new List<SerializedTestData<ICPU>>() {
            new SerializedTestData<ICPU>(new CPU(), "{\"CPUSignil\":{\"CPUMaker\":0,\"CPUSocket\":0,\"NumberOfPhysicalCores\":0,\"CoreClockNominal\":\"0 Hz\",\"CoreVoltageNominal\":\"0 Vdc\"},\"Philote\":null}")
          })
      };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
