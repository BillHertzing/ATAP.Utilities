using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using System;
using ATAP.Utilities.ComputerInventory.Models.Hardware;

namespace ATAP.Utilities.ComputerInventory.UnitTests
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
      yield return new CPUArrayTestData[] { new CPUArrayTestData { CPUArray = new CPU[] { new CPU(CPUMaker.Generic) }, SerializedCPUArray = "[{\"CPUMaker\":0}]" } };
      yield return new CPUArrayTestData[] { new CPUArrayTestData { CPUArray = new CPU[] { new CPU(CPUMaker.Intel) }, SerializedCPUArray = "[{\"CPUMaker\":1}]" } };
      yield return new CPUArrayTestData[] { new CPUArrayTestData { CPUArray = new CPU[] { new CPU(CPUMaker.AMD) }, SerializedCPUArray = "[{\"CPUMaker\":2}]" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return CPUArrayTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
