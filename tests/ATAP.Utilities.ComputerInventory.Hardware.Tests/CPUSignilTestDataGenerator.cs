using System.Collections.Generic;
using System.Collections;

using System;
using System.Text;
using ATAP.Utilities.Testing;
using ATAP.Utilities.ComputerInventory.Hardware;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class CPUSignilTestData : TestData<CPUSignil>
  {
    public CPUSignilTestData(CPUSignil objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class CPUSignilTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      StringBuilder str = new StringBuilder();
      foreach (CPUMakerTestData[] maker in CPUMakerTestDataGenerator.TestData())
      {
        foreach (CPUSocketTestData[] socket in CPUSocketTestDataGenerator.TestData())
        {
          str.Clear();
          str.Append($"{{\"CPUMaker\":{maker[0].SerializedTestData},\"CPUSocket\":{socket[0].SerializedTestData},\"NumberOfPhysicalCores\":6,\"CoreClockNominal\":\"1.8 GHz\",\"CoreVoltageNominal\":\"1 Vdc\"}}");
          yield return new CPUSignilTestData[] {
            new CPUSignilTestData(
              new CPUSignil(
                maker[0].ObjTestData,
                socket[0].ObjTestData,
                6,
                new UnitsNet.Frequency(1.8 , UnitsNet.Units.FrequencyUnit.Gigahertz),
                new UnitsNet.ElectricPotentialDc(1.0, UnitsNet.Units.ElectricPotentialDcUnit.VoltDc)
              ),
              str.ToString())};
        }
      }
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
