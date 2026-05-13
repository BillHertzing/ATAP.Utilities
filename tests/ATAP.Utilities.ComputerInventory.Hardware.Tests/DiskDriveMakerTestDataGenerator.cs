using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{


  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class DiskDriveMakerTestData : TestData<DiskDriveMaker>
  {
    public DiskDriveMakerTestData(DiskDriveMaker objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class DiskDriveMakerTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new DiskDriveMakerTestData[] { new DiskDriveMakerTestData(DiskDriveMaker.Generic,  "0" ) };
      yield return new DiskDriveMakerTestData[] { new DiskDriveMakerTestData(DiskDriveMaker.Hitachi, "1" )};
      yield return new DiskDriveMakerTestData[] { new DiskDriveMakerTestData(DiskDriveMaker.Maxtor, "2") };
      yield return new DiskDriveMakerTestData[] { new DiskDriveMakerTestData(DiskDriveMaker.Samsung, "3") };
      yield return new DiskDriveMakerTestData[] { new DiskDriveMakerTestData(DiskDriveMaker.Seagate, "4") };
      yield return new DiskDriveMakerTestData[] { new DiskDriveMakerTestData(DiskDriveMaker.WesternDigital, "5") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
