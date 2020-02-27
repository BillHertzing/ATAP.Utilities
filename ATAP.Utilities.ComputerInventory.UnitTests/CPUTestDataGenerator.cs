using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Enumerations;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using System;

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class CPUTestData
  {
    public CPU CPU;
    public string SerializedCPU;

    public CPUTestData()
    {
    }

    public CPUTestData(CPU cPU, string serializedCPU)
    {
      CPU = cPU ?? throw new ArgumentNullException(nameof(cPU));
      SerializedCPU = serializedCPU ?? throw new ArgumentNullException(nameof(serializedCPU));
    }
  }

  public class CPUTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> CPUTestData()
    {
      yield return new CPUTestData[] { new CPUTestData { CPU = new CPU(CPUMaker.Generic), SerializedCPU = "{\"Maker\":0}" } };
      yield return new CPUTestData[] { new CPUTestData { CPU = new CPU(CPUMaker.Intel), SerializedCPU = "{\"Maker\":1}" } };
      yield return new CPUTestData[] { new CPUTestData { CPU = new CPU(CPUMaker.AMD), SerializedCPU = "{\"Maker\":2}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return CPUTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
