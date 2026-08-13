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
    [MemberData(nameof(CPUSocketTestDataGenerator.TestData), MemberType = typeof(CPUSocketTestDataGenerator))]
    public void CPUSocketDeserializeFromJSON(CPUSocketTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<CPUSocket>(inTestData.TestData);
      ((object)obj).Should().BeOfType<CPUSocket>();
      Fixture.Serializer.Deserialize<CPUSocket>(inTestData.TestData).Should().Be(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(CPUSocketTestDataGenerator.TestData), MemberType = typeof(CPUSocketTestDataGenerator))]
    public void CPUSocketSerializeToJSON(CPUSocketTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.TestData);
    }
  }
}
