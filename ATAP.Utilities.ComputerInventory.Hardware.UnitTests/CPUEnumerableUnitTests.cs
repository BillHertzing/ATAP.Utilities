using ATAP.Utilities.Testing;
using FluentAssertions;
using Itenso.TimePeriod;
using System.Collections.Generic;
using Xunit;
using Xunit.Abstractions;
using System.Linq;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{


  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<ComputerInventoryHardwareFixture>
  {
    [Theory]
    [MemberData(nameof(CPUEnumerableTestDataGenerator.TestData), MemberType = typeof(CPUEnumerableTestDataGenerator))]
    public void CPUEnumerableDeserializeFromJSON(CPUEnumerableTestData inTestData)
    {
      foreach (var itb in inTestData.E)
      {
        var obj = Fixture.Serializer.Deserialize<IEnumerable<ITimeBlock>>(itb.SerializedTestData);
        obj.Should().BeOfType(typeof(IEnumerable<ITimeBlock>));
        Fixture.Serializer.Deserialize<IEnumerable<ITimeBlock>>(itb.SerializedTestData).Should().BeEquivalentTo(itb.ObjTestData);
      }

      // ToDo loop over every element of the enumerable and test eah one

    }

    [Theory]
    [MemberData(nameof(CPUEnumerableTestDataGenerator.TestData), MemberType = typeof(CPUEnumerableTestDataGenerator))]
    public void CPUEnumerableSerializeToJSON(CPUEnumerableTestData inTestData)
    {
#if DEBUG
      TestOutput.WriteLine("Starting " + nameof(CPUEnumerableSerializeToJSON));
#endif
      foreach (var e in inTestData.E)
      {
#if DEBUG
        TestOutput.WriteLine("SerializedTestData is:" + e.SerializedTestData);
        TestOutput.WriteLine("Serialized ObjTestData is:" + Fixture.Serializer.Serialize(e.ObjTestData));
#endif
        Fixture.Serializer.Serialize(e.ObjTestData).Should().Be(e.SerializedTestData);
#if DEBUG
        TestOutput.WriteLine("Ending " + nameof(CPUEnumerableSerializeToJSON));
#endif
      }
    }
  }
}
