using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<ComputerInventoryHardwareFixture>
  {
    [@Fact]
    [MemberData(nameof(MainBoardTestDataGenerator.TestData), MemberType = typeof(MainBoardTestDataGenerator))]
    public void MainBoardDeserializeFromJSON(MainBoardTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<MainBoard>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(MainBoard));
      Fixture.Serializer.Deserialize<MainBoard>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(MainBoardTestDataGenerator.TestData), MemberType = typeof(MainBoardTestDataGenerator))]
    public void MainBoardSerializeToJSON(MainBoardTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().BeEquivalentTo(inTestData.SerializedTestData);
    }
  }
}
