
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
    /*
    [SkipBecauseNotWorkingTheory]
    [MemberData(nameof(CPUTestDataGenerator.TestData), MemberType = typeof(CPUTestDataGenerator))]
    public void CPUDeserializeFromJSON(CPUTestData inTestData)
    {
#if DEBUG
      TestOutput.WriteLine("SerializedTestData is:" + inTestData.SerializedTestDataArray[0]);
      TestOutput.WriteLine("Serialized ObjTestData is:" + DiFixture.Serializer.Serialize(inTestData.ObjTestDataArray[0]));
#endif
      var obj = DiFixture.Serializer.Deserialize<CPU[]>(inTestData.SerializedTestDataArray[0]);
      obj.Should().BeOfType(typeof(CPU[]));
      DiFixture.Serializer.Deserialize<CPU>(inTestData.SerializedTestDataArray[0]).Should().BeEquivalentTo(inTestData.ObjTestDataArray[0]);
    }

    [Theory]
    [MemberData(nameof(CPUTestDataGenerator.TestData), MemberType = typeof(CPUTestDataGenerator))]
    public void CPUSerializeToJSON(CPUTestData inTestData)
    {
#if DEBUG
      TestOutput.WriteLine("SerializedTestData is:" + inTestData.SerializedTestDataArray[0]);
      TestOutput.WriteLine("Serialized ObjTestData is:" + DiFixture.Serializer.Serialize(inTestData.ObjTestDataArray[0]));
#endif
      DiFixture.Serializer.Serialize(inTestData.ObjTestDataArray[0]).Should().BeEquivalentTo(inTestData.SerializedTestDataArray[0]);
    }
    */
  }
}
