using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using System;

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{
  public class CPUArrayTestData
  {
    public CPU[] CPUArray;
    public string SerializedCPUArray;

    public CPUArrayTestData()
    {
    }

    public CPUArrayTestData(CPU[] cPUArray, string serializedCPUArray)
    {
      CPUArray = cPUArray ?? throw new ArgumentNullException(nameof(cPUArray));
      SerializedCPUArray = serializedCPUArray ?? throw new ArgumentNullException(nameof(serializedCPUArray));
    }
  }

  public class CPUArrayTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> CPUArrayTestData()
    {
      yield return new CPUArrayTestData[] { new CPUArrayTestData { CPUArray = new CPU[] { new CPU(CPUMaker.Generic) }, SerializedCPUArray = "[{\"Maker\":0}]" } };
      yield return new CPUArrayTestData[] { new CPUArrayTestData { CPUArray = new CPU[] { new CPU(CPUMaker.Intel) }, SerializedCPUArray = "[{\"Maker\":1}]" } };
      yield return new CPUArrayTestData[] { new CPUArrayTestData { CPUArray = new CPU[] { new CPU(CPUMaker.AMD) }, SerializedCPUArray = "[{\"Maker\":2}]" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return CPUArrayTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
