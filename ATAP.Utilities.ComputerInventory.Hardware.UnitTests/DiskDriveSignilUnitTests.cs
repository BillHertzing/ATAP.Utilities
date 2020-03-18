using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<ComputerInventoryHardwareFixture>
  {
    [SkipBecauseNotWorkingTheory]
    [MemberData(nameof(DiskDriveSignilTestDataGenerator.TestData), MemberType = typeof(DiskDriveSignilTestDataGenerator))]
    public void DiskDriveSignilDeserializeFromJSON(DiskDriveSignilTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<DiskDriveSignil>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(DiskDriveSignil));
      Fixture.Serializer.Deserialize<DiskDriveSignil>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(DiskDriveSignilTestDataGenerator.TestData), MemberType = typeof(DiskDriveSignilTestDataGenerator))]
    public void DiskDriveSignilSerializeToJSON(DiskDriveSignilTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }
  }
}
