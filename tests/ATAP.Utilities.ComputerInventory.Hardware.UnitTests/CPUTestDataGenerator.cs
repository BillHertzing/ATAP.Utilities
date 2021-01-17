using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using System.Text;
using ATAP.Utilities.Testing;
using ATAP.Utilities.StronglyTypedIDs;
using Itenso.TimePeriod;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class CPUTestData : TestData<ICPU>
  {
    public CPUTestData(CPU objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class CPUTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      StringBuilder str = new StringBuilder();
      foreach (CPUSignilTestData[] signil in CPUSignilTestDataGenerator.TestData())
      {
        foreach (PhiloteTestData<ICPU>[] philote in PhiloteTestDataGenerator<ICPU>.TestData())
        {
          str.Clear();
          str.Append($"{{\"CPUSignil\":{signil[0].SerializedTestData},\"Philote\":{philote[0].SerializedTestData}}}");
          yield return new CPUTestData[] { new CPUTestData(new CPU(signil[0].ObjTestData, philote[0].ObjTestData), str.ToString()) };
          //yield return new CPUTestData[] { new CPUTestData(new CPU[2] { new CPU(signil[0].ObjTestData, id[0], timeBlock[0].ObjTestData), new CPU(signil[0].ObjTestData, id[1], timeBlock[0].ObjTestData) }, new string[2] { str[0].ToString(), String[1].ToString() }) };
          //yield return new CPUTestData[] { new CPUTestData(new CPU(signil[0].ObjTestData, id[0], timeBlock[0].ObjTestData), str.ToString()) };
        }
      }
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
