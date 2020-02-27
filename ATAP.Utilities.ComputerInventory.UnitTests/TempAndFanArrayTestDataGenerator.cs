using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Configuration.Hardware;
using System;

namespace ATAP.Utilities.ComputerInventory.Configuration.UnitTests
{
  public class TempAndFanArrayTestData
  {
    public TempAndFan[] TempAndFanArray;
    public string SerializedTempAndFanArray;

    public TempAndFanArrayTestData()
    {
    }

    public TempAndFanArrayTestData(TempAndFan[] tempAndFanArray, string serializedTempAndFanArray)
    {
      TempAndFanArray = tempAndFanArray ?? throw new ArgumentNullException(nameof(tempAndFanArray));
      SerializedTempAndFanArray = serializedTempAndFanArray ?? throw new ArgumentNullException(nameof(serializedTempAndFanArray));
    }
  }

  public class TempAndFanArrayTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TempAndFanArrayTestData()
    {
      yield return new TempAndFanArrayTestData[] { new TempAndFanArrayTestData { TempAndFanArray = new TempAndFan[] { new TempAndFan { Temp = 50, FanPct = 100 } }, SerializedTempAndFanArray = "[{\"Temp\":50,\"FanPct\":100}]" }, };
      yield return new TempAndFanArrayTestData[] { new TempAndFanArrayTestData { TempAndFanArray = new TempAndFan[] { new TempAndFan { Temp = 50.1, FanPct = 100.1 } }, SerializedTempAndFanArray = "[{\"Temp\":50.1,\"FanPct\":100.1}]" }, };
    }
    public IEnumerator<object[]> GetEnumerator() { return TempAndFanArrayTestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
