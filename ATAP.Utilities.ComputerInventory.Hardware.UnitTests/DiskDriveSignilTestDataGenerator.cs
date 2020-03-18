using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using System.Text;
using ATAP.Utilities.Testing;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class DiskDriveSignilTestData : TestData<DiskDriveSignil>
  {
    public DiskDriveSignilTestData(DiskDriveSignil objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class DiskDriveSignilTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      StringBuilder str = new StringBuilder();
      foreach (DiskDriveMakerTestData[] diskDriveMaker in DiskDriveMakerTestDataGenerator.TestData())
      {
        foreach (DiskDriveTypeTestData[] diskDriveType in DiskDriveTypeTestDataGenerator.TestData())
        {
          foreach (UnitsNetInformationTestData[] diskDriveInformation in UnitsNetInformationTestDataGenerator.TestData())
          {
            str.Clear();
            str.Append($"{{\"DiskDriveMaker\":{diskDriveMaker[0].SerializedTestData},\"DiskDriveType\":{diskDriveType[0].SerializedTestData},\"InformationSize\":{diskDriveInformation[0].SerializedTestData}}}");
            yield return new DiskDriveSignilTestData[] {
            new DiskDriveSignilTestData(
              new DiskDriveSignil(
                diskDriveMaker[0].ObjTestData,
                diskDriveType[0].ObjTestData,
                diskDriveInformation[0].ObjTestData
              ),
              str.ToString())};
          }
        }
      }
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
