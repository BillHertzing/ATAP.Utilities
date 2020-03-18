using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{

  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<ComputerInventoryHardwareFixture>
  {
    [Theory]
    [MemberData(nameof(MainBoardMakerTestDataGenerator.TestData), MemberType = typeof(MainBoardMakerTestDataGenerator))]
    public void MainBoardMakerDeserializeFromJSON(MainBoardMakerTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<MainBoardMaker>(inTestData.SerializedMainBoardMaker);
      obj.Should().BeOfType(typeof(MainBoardMaker));
      Fixture.Serializer.Deserialize<MainBoardMaker>(inTestData.SerializedMainBoardMaker).Should().Be(inTestData.MainBoardMaker);
    }

    [Theory]
    [MemberData(nameof(MainBoardMakerTestDataGenerator.TestData), MemberType = typeof(MainBoardMakerTestDataGenerator))]
    public void MainBoardMakerSerializeToJSON(MainBoardMakerTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.MainBoardMaker).Should().Be(inTestData.SerializedMainBoardMaker);
    }

  }
}
