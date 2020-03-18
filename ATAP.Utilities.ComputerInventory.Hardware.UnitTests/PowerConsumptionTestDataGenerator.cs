using System;
using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using ATAP.Utilities.ComputerInventory.Models.Hardware;
using Itenso.TimePeriod;

namespace ATAP.Utilities.ComputerInventory.UnitTests
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
      yield return new PowerConsumptionTestData[] { new PowerConsumptionTestData { PowerConsumption = new PowerConsumption(
        new TimeSpan(1,0,0), new UnitsNet.Power(1,UnitsNet.Units.PowerUnit.Watt)),
        SerializedPowerConsumption = "{\"TimeSpan\":\"01:00:00\",\"Power\":1}" } };
      yield return new PowerConsumptionTestData[] { new PowerConsumptionTestData { PowerConsumption = new PowerConsumption(
        new TimeSpan(0,0,0), new UnitsNet.Power(0.01m,UnitsNet.Units.PowerUnit.Watt)),
        SerializedPowerConsumption = "{\"TimeSpan\":00:00:00,\"Power\":10.0}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return PowerConsumptionTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
