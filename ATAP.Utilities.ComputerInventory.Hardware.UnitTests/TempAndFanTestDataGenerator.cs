using System.Collections.Generic;
using System.Collections;
using System;
using UnitsNet;
using ATAP.Utilities.ComputerInventory.Hardware;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{
  public class TempAndFanTestData
  {
    public TempAndFan TempAndFan;
    public string SerializedTempAndFan;

    public TempAndFanTestData() { }

    public TempAndFanTestData(TempAndFan tempAndFan, string serializedTempAndFan)
    {
      TempAndFan = tempAndFan ?? throw new ArgumentNullException(nameof(tempAndFan));
      SerializedTempAndFan = serializedTempAndFan ?? throw new ArgumentNullException(nameof(serializedTempAndFan));
    }
  }

  public class TempAndFanTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TempAndFanTestData()
    {
      yield return new TempAndFanTestData[] {
        new TempAndFanTestData { TempAndFan =  new TempAndFan() {
            Temp = new Temperature(50, UnitsNet.Units.TemperatureUnit.DegreeFahrenheit),
            FanPct = new Ratio(95.5, UnitsNet.Units.RatioUnit.Percent) },
        SerializedTempAndFan = "{\"Temp\":50,\"FanPct\":95.5}" } };
      yield return new TempAndFanTestData[] {
        new TempAndFanTestData { TempAndFan =  new TempAndFan() {
            Temp = new Temperature(50, UnitsNet.Units.TemperatureUnit.DegreeFahrenheit),
            FanPct = new Ratio(95.5, UnitsNet.Units.RatioUnit.Percent) },
        SerializedTempAndFan = "{\"Temp\":50,\"FanPct\":95.5}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return TempAndFanTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
