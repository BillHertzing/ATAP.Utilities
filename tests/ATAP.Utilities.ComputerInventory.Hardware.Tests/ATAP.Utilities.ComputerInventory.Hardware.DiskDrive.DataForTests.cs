using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using System.Text;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.Tests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class DiskDriveTestData : SerializedTestData<DiskDrive>
  {
    public DiskDriveTestData(DiskDrive objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class DiskDriveTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      StringBuilder str = new StringBuilder();
      foreach (DiskDriveSignilTestData[] signil in DiskDriveSignilTestDataGenerator.TestData())
      {
        foreach (PhiloteTestData<IDiskDrive>[] philote in PhiloteTestDataGenerator<IDiskDrive>.TestData())
        {
          str.Clear();
          str.Append($"{{\"DiskDriveSignil\":{signil[0].TestData},\"DiskDriveNumber\":0,\"Philote\":{philote[0].TestData}}}");
          yield return new DiskDriveTestData[] { new DiskDriveTestData(new DiskDrive(signil[0].ObjTestData,0, philote[0].ObjTestData), str.ToString()) };
        }
        //}

      }
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
