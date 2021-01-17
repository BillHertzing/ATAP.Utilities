using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using System.Text;
using ATAP.Utilities.Testing;
using ATAP.Utilities.StronglyTypedIDs;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class DiskDriveTestData : TestData<DiskDrive>
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
          str.Append($"{{\"DiskDriveSignil\":{signil[0].SerializedTestData},\"DiskDriveNumber\":0,\"Philote\":{philote[0].SerializedTestData}}}");
          yield return new DiskDriveTestData[] { new DiskDriveTestData(new DiskDrive(signil[0].ObjTestData,0, philote[0].ObjTestData), str.ToString()) };
        }
        //}

      }
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
