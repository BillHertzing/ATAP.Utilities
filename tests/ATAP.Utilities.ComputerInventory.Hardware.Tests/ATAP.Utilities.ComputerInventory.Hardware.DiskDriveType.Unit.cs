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
    [MemberData(nameof(DiskDriveTypeTestDataGenerator.TestData), MemberType = typeof(DiskDriveTypeTestDataGenerator))]
    public void DiskDriveTypeDeserializeFromJSON(DiskDriveTypeTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<DiskDriveType>(inTestData.TestData);
      ((object)obj).Should().BeOfType<DiskDriveType>();
      Fixture.Serializer.Deserialize<DiskDriveType>(inTestData.TestData).Should().Be(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(DiskDriveTypeTestDataGenerator.TestData), MemberType = typeof(DiskDriveTypeTestDataGenerator))]
    public void DiskDriveTypeSerializeToJSON(DiskDriveTypeTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.TestData);
    }

  }
}
