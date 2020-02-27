using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using System;

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
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
      yield return new TempAndFanTestData[] { new TempAndFanTestData { TempAndFan = new TempAndFan { Temp = 50, FanPct = 95.5 }, SerializedTempAndFan = "{\"Temp\":50,\"FanPct\":95.5}" } };
      yield return new TempAndFanTestData[] { new TempAndFanTestData { TempAndFan = new TempAndFan { Temp = 0.0, FanPct = 100.0 }, SerializedTempAndFan = "{\"Temp\":0,\"FanPct\":100}" } };
    }
    public IEnumerator<object[]> GetEnumerator() { return TempAndFanTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
