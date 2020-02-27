using System;
using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{
  public class PowerConsumptionTestData
  {
    public PowerConsumption PowerConsumption;
    public string SerializedPowerConsumption;

    public PowerConsumptionTestData() { }

    public PowerConsumptionTestData(PowerConsumption PowerConsumption, string serializedPowerConsumption)
    {
      PowerConsumption = PowerConsumption ?? throw new ArgumentNullException(nameof(PowerConsumption));
      SerializedPowerConsumption = serializedPowerConsumption ?? throw new ArgumentNullException(nameof(serializedPowerConsumption));
    }
  }

  public class PowerConsumptionTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> PowerConsumptionTestData()
    {
      yield return new PowerConsumptionTestData[] { new PowerConsumptionTestData { PowerConsumption = new PowerConsumption(10.0, new TimeSpan(0, 0, 1)), SerializedPowerConsumption = "{\"Period\":\"00:00:01\",\"Watts\":1000.0}" } };
      yield return new PowerConsumptionTestData[] { new PowerConsumptionTestData { PowerConsumption = new PowerConsumption(1.0, new TimeSpan(0, 1, 0)), SerializedPowerConsumption = "{\"Period\":00:01:00,\"Watts\":10.0}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return PowerConsumptionTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
