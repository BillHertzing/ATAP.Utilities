using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<ComputerInventoryHardwareFixture>
  {
    [Theory]
    [MemberData(nameof(DiskDriveTypeTestDataGenerator.TestData), MemberType = typeof(DiskDriveTypeTestDataGenerator))]
    public void DiskDriveTypeDeserializeFromJSON(DiskDriveTypeTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<DiskDriveType>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(DiskDriveType));
      Fixture.Serializer.Deserialize<DiskDriveType>(inTestData.SerializedTestData).Should().Be(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(DiskDriveTypeTestDataGenerator.TestData), MemberType = typeof(DiskDriveTypeTestDataGenerator))]
    public void DiskDriveTypeSerializeToJSON(DiskDriveTypeTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }

  }
}
