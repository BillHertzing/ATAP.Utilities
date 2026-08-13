
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
    [MemberData(nameof(CPUSignilTestDataGenerator.TestData), MemberType = typeof(CPUSignilTestDataGenerator))]
    public void CPUSignilDeserializeFromJSON(CPUSignilTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<CPUSignil>(inTestData.TestData);
      obj.Should().BeOfType(typeof(CPUSignil));
      Fixture.Serializer.Deserialize<CPUSignil>(inTestData.TestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(CPUSignilTestDataGenerator.TestData), MemberType = typeof(CPUSignilTestDataGenerator))]
    public void CPUSignilSerializeToJSON(CPUSignilTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.TestData);
    }
  }
}
