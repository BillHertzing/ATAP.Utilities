using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.Tests
{
  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class DiskDriveEnumerableTestData : TestDataEn<IDiskDrive>
  {
    public DiskDriveEnumerableTestData(IEnumerable<SerializedTestData<IDiskDrive>> e) : base(e)
    {
    }
  }
  public class DiskDriveEnumerableTestDataGenerator : IEnumerable<object[]>
  {
    public static DiskDrive DiskDriveStaticDefault = new DiskDrive();
    public static SerializedTestData<IDiskDrive> DiskDriveTestDataStaticDefault = new SerializedTestData<IDiskDrive>(DiskDriveStaticDefault, "{\"DiskDriveSignil\":\"stuff\"");
    public static IEnumerable<object[]> TestData()
    {
      // An empty list
      yield return new DiskDriveEnumerableTestData[] { new DiskDriveEnumerableTestData(new List<SerializedTestData<IDiskDrive>>()) };
      // a list with just the default instance of the type
      yield return new DiskDriveEnumerableTestData[] { new DiskDriveEnumerableTestData(new List<SerializedTestData<IDiskDrive>>()) };

      /*
       *foreach (DiskDriveSignilTestData[] signil in DiskDriveSignilTestDataGenerator.TestData())
            {
                var id1 = new List<IdAsStruct<IDiskDrive>> { new IdAsStruct<IDiskDrive>(Guid.NewGuid()), new IdAsStruct<IDiskDrive>(Guid.NewGuid()) };
        var id2 = new List<IdAsStruct<IDiskDrive>> { new IdAsStruct<IDiskDrive>(Guid.NewGuid()), new IdAsStruct<IDiskDrive>(Guid.NewGuid()) };
        var timeBlocks = TimeBlockTestDataGenerator.TestData();
                //DiskDrive DiskDrive = new DiskDrive(signil,id1.G)
                for (int i = 0; i<numObjects; i++) {
                //foreach (IdAsStruct<IDiskDrive>id[] in IdTestDataGenerator.TestData(IDiskDrive))
                //{
                  //str[i].Clear();
                  //str[i].Append($"{{\"DiskDriveSignil\":{signil[0].TestData},\"ID\":\"{id[i]}\",\"TimeBlock\":{timeBlock[0].TestData}}}");
                  yield return new DiskDriveEnTestData { new DiskDriveEnTestData(new DiskDrive[1] { new DiskDrive(signil[0].ObjTestData, id[0], timeBlock[0].ObjTestData) }, new string[1] { str[0].ToString() }) };
                  //yield return new DiskDriveTestData[] { new DiskDriveTestData(new DiskDrive[2] { new DiskDrive(signil[0].ObjTestData, id[0], timeBlock[0].ObjTestData), new DiskDrive(signil[0].ObjTestData, id[1], timeBlock[0].ObjTestData) }, new string[2] { str[0].ToString(), String[1].ToString() }) };
                  //yield return new DiskDriveTestData[] { new DiskDriveTestData(new DiskDrive(signil[0].ObjTestData, id[0], timeBlock[0].ObjTestData), str.ToString()) };
                }
              }
            }
              */
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
