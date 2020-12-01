
using ATAP.Utilities.Testing;
using FluentAssertions;
using Itenso.TimePeriod;
using System.Collections.Generic;
using Xunit;
using Xunit.Abstractions;
using System.Linq;
using ATAP.Utilities.ComputerInventory.Hardware;

namespace ATAP.Utilities.ComputerInventory.Hardware.UnitTests
{


  public partial class ComputerInventoryHardwareUnitTests001 : IClassFixture<ComputerInventoryHardwareFixture>
  {
    [Theory]
    [MemberData(nameof(DiskDriveEnumerableTestDataGenerator.TestData), MemberType = typeof(DiskDriveEnumerableTestDataGenerator))]
    public void DiskDriveEnumerableDeserializeFromJSON(DiskDriveEnumerableTestData inTestData)
    {
      foreach (var e in inTestData.E)
      {
        var obj = Fixture.Serializer.Deserialize<IEnumerable<IDiskDrive>>(e.SerializedTestData);
        obj.Should().BeOfType(typeof(IEnumerable<IDiskDrive>));
        Fixture.Serializer.Deserialize<IEnumerable<IDiskDrive>>(e.SerializedTestData).Should().BeEquivalentTo(e.ObjTestData);
      }

      // ToDo loop over every element of the enumerable and test eah one

    }

    [Theory]
    [MemberData(nameof(DiskDriveEnumerableTestDataGenerator.TestData), MemberType = typeof(DiskDriveEnumerableTestDataGenerator))]
    public void DiskDriveEnumerableSerializeToJSON(DiskDriveEnumerableTestData inTestData)
    {
#if DEBUG
      TestOutput.WriteLine("Starting " + nameof(DiskDriveEnumerableSerializeToJSON));
#endif
      foreach (var e in inTestData.E)
      {
#if DEBUG
        TestOutput.WriteLine("SerializedTestData is:" + e.SerializedTestData);
        TestOutput.WriteLine("Serialized ObjTestData is:" + Fixture.Serializer.Serialize(e.ObjTestData));
#endif
        Fixture.Serializer.Serialize(e.ObjTestData).Should().Be(e.SerializedTestData);
#if DEBUG
        TestOutput.WriteLine("Ending " + nameof(DiskDriveEnumerableSerializeToJSON));
#endif
      }
    }
  }
}
