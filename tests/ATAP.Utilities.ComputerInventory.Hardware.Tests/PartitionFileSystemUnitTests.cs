using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<Fixture>
  {
    [Theory]
    [MemberData(nameof(PartitionFileSystemTestDataGenerator.TestData), MemberType = typeof(PartitionFileSystemTestDataGenerator))]
    public void PartitionFileSystemDeserializeFromJSON(PartitionFileSystemTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<PartitionFileSystem>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(PartitionFileSystem));
      Fixture.Serializer.Deserialize<PartitionFileSystem>(inTestData.SerializedTestData).Should().Be(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(PartitionFileSystemTestDataGenerator.TestData), MemberType = typeof(PartitionFileSystemTestDataGenerator))]
    public void PartitionFileSystemSerializeToJSON(PartitionFileSystemTestData inTestData)
    {
#if DEBUG
      TestOutput.WriteLine("SerializedTestData is:" + inTestData.SerializedTestData);
      TestOutput.WriteLine("Serialized ObjTestData is:" + Fixture.Serializer.Serialize(inTestData.ObjTestData));
#endif
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }

  }
}
