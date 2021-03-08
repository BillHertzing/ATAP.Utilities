using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using System.Text;
using ATAP.Utilities.Testing;
using ATAP.Utilities.StronglyTypedID;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class PartitionInfoExTestData : TestData<PartitionInfoEx>
  {
    public PartitionInfoExTestData(PartitionInfoEx objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class PartitionInfoExTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      StringBuilder str = new StringBuilder();
      foreach (PartitionFileSystemTestData[] partitionFileSystem in PartitionFileSystemTestDataGenerator.TestData())
      {
        foreach (UnitsNetInformationTestData[] information in UnitsNetInformationTestDataGenerator.TestData())
        {
          IEnumerable<char> driveLetters = new List<char>() { 'E' };
          foreach (PhiloteTestData<IPartitionInfoEx>[] philote in PhiloteTestDataGenerator<IPartitionInfoEx>.TestData())
          {
            var X = new PartitionInfoEx(partitionFileSystem[0].ObjTestData, information[0].ObjTestData, driveLetters, philote[0].ObjTestData);
            str.Clear();
            str.Append($"{{\"PartitionFileSystem\":{partitionFileSystem[0].SerializedTestData},\"Size\":{information[0].SerializedTestData},\"DriveLetters\":[\"E\"],\"Philote\":{philote[0].SerializedTestData}}}");

            yield return new PartitionInfoExTestData[] { new PartitionInfoExTestData(new PartitionInfoEx(partitionFileSystem[0].ObjTestData, information[0].ObjTestData, driveLetters, philote[0].ObjTestData), str.ToString()) };
            //yield return new PartitionInfoExTestData[] { new PartitionInfoExTestData(new PartitionInfoEx(idpair.ID, idpair.ID2, new string[1] {"X"}, partitionFileSystem[0].ObjTestData, information[0].ObjTestData), str.ToString()) };
          }
        }
        //}
      }
    }

    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }
}
