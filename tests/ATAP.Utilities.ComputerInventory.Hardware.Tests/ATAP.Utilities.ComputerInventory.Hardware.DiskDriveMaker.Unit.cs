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
    [MemberData(nameof(DiskDriveMakerTestDataGenerator.TestData), MemberType = typeof(DiskDriveMakerTestDataGenerator))]
    public void DiskDriveMakerDeserializeFromJSON(DiskDriveMakerTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<DiskDriveMaker>(inTestData.TestData);
      ((object)obj).Should().BeOfType<DiskDriveMaker>();
      Fixture.Serializer.Deserialize<DiskDriveMaker>(inTestData.TestData).Should().Be(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(DiskDriveMakerTestDataGenerator.TestData), MemberType = typeof(DiskDriveMakerTestDataGenerator))]
    public void DiskDriveMakerSerializeToJSON(DiskDriveMakerTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.TestData);
    }

  }
}
