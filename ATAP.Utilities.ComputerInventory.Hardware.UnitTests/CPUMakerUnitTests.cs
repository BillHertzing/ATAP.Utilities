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
    [MemberData(nameof(CPUMakerTestDataGenerator.TestData), MemberType = typeof(CPUMakerTestDataGenerator))]
    public void CPUMakerDeserializeFromJSON(CPUMakerTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<CPUMaker>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(CPUMaker));
      Fixture.Serializer.Deserialize<CPUMaker>(inTestData.SerializedTestData).Should().Be(inTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(CPUMakerTestDataGenerator.TestData), MemberType = typeof(CPUMakerTestDataGenerator))]
    public void CPUMakerSerializeToJSON(CPUMakerTestData inTestData)
    {
#if DEBUG
      TestOutput.WriteLine("SerializedTestData is:" + inTestData.SerializedTestData);
      TestOutput.WriteLine("Serialized ObjTestData is:" + Fixture.Serializer.Serialize(inTestData.ObjTestData));
#endif
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }

  }
}
