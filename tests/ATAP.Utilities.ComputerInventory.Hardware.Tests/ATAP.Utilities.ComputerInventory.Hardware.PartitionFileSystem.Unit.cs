using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Hardware.Tests
{

  [Trait("Category", "Unit")]
  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<Fixture>
  {
    [Theory]
    [MemberData(nameof(PartitionFileSystemTestDataGenerator.TestData), MemberType = typeof(PartitionFileSystemTestDataGenerator))]
    public void PartitionFileSystemDeserializeFromJSON(PartitionFileSystemTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<PartitionFileSystem>(inTestData.TestData);
      ((object)obj).Should().BeOfType<PartitionFileSystem>();
      Fixture.Serializer.Deserialize<PartitionFileSystem>(inTestData.TestData).Should().Be(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(PartitionFileSystemTestDataGenerator.TestData), MemberType = typeof(PartitionFileSystemTestDataGenerator))]
    public void PartitionFileSystemSerializeToJSON(PartitionFileSystemTestData inTestData)
    {
#if DEBUG
      TestOutput.WriteLine("SerializedTestData is:" + inTestData.TestData);
      TestOutput.WriteLine("Serialized ObjTestData is:" + Fixture.Serializer.Serialize(inTestData.ObjTestData));
#endif
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.TestData);
    }

  }
}
