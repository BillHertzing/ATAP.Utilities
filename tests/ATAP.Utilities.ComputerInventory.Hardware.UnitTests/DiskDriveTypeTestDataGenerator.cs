using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{


  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class DiskDriveTypeTestData : TestData<DiskDriveType>
  {
    public DiskDriveTypeTestData(DiskDriveType objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class DiskDriveTypeTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new DiskDriveTypeTestData[] { new DiskDriveTypeTestData(DiskDriveType.Generic, "0") };
      yield return new DiskDriveTypeTestData[] { new DiskDriveTypeTestData(DiskDriveType.HDD, "1") };
      yield return new DiskDriveTypeTestData[] { new DiskDriveTypeTestData(DiskDriveType.SSD, "2") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
