
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<Fixture>
  {
    [@Fact]
    [MemberData(nameof(DiskDriveTestDataGenerator.TestData), MemberType = typeof(DiskDriveTestDataGenerator))]
    public void DiskDriveDeserializeFromJSON(DiskDriveTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<DiskDrive>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(DiskDrive));
      Fixture.Serializer.Deserialize<DiskDrive>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(DiskDriveTestDataGenerator.TestData), MemberType = typeof(DiskDriveTestDataGenerator))]
    public void DiskDriveSerializeToJSON(DiskDriveTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().BeEquivalentTo(inTestData.SerializedTestData);
    }
  }
}
