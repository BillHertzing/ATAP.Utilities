using System.Collections.Generic;
using System.Collections;
using ATAP.Utilities.ComputerInventory.Hardware;
using System;
using ATAP.Utilities.Testing;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{


  //ToDo add validation tests to ensure illegal values are not allowed.  This applies to all XxTestDataGenerator classes
  public class PartitionFileSystemTestData : TestData<PartitionFileSystem>
  {
    public PartitionFileSystemTestData(PartitionFileSystem objTestData, string serializedTestData) : base(objTestData, serializedTestData)
    {
    }
  }

  public class PartitionFileSystemTestDataGenerator : IEnumerable<object[]>
  {
    public static IEnumerable<object[]> TestData()
    {
      yield return new PartitionFileSystemTestData[] { new PartitionFileSystemTestData(PartitionFileSystem.Generic, "0") };
      yield return new PartitionFileSystemTestData[] { new PartitionFileSystemTestData(PartitionFileSystem.NTFS, "1") };
      yield return new PartitionFileSystemTestData[] { new PartitionFileSystemTestData(PartitionFileSystem.FAT32, "2") };
    }
    public IEnumerator<object[]> GetEnumerator() { return TestData().GetEnumerator(); }
    IEnumerator IEnumerable.GetEnumerator() { return GetEnumerator(); }
  }

}
