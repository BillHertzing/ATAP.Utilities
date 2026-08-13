
using ATAP.Utilities.ComputerInventory.Hardware;
using ATAP.Utilities.Testing.XunitSkipAttributeExtension;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Hardware.Tests
{

  [Trait("Category", "Unit")]
  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<Fixture>
  {
    [Theory]
    [MemberData(nameof(MainBoardSignilTestDataGenerator.TestData), MemberType = typeof(MainBoardSignilTestDataGenerator))]
    public void MainBoardSignilDeserializeFromJSON(MainBoardSignilTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<MainBoardSignil>(inTestData.TestData);
      obj.Should().BeOfType(typeof(MainBoardSignil));
      Fixture.Serializer.Deserialize<MainBoardSignil>(inTestData.TestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(MainBoardSignilTestDataGenerator.TestData), MemberType = typeof(MainBoardSignilTestDataGenerator))]
    public void MainBoardSignilSerializeToJSON(MainBoardSignilTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().BeEquivalentTo(inTestData.TestData);
    }
  }
}
