using FluentAssertions;
using Xunit;

using ATAP.Utilities.ComputerInventory.Software;

namespace ATAP.Utilities.ComputerInventory.Software.UnitTests
{


  public partial class ComputerInventorySoftwareUnitTests001 : IClassFixture<ComputerInventorySoftwareFixture>
  {
 
    [Theory]
    [MemberData(nameof(ComputerSoftwareProgramTestDataGenerator.TestData), MemberType = typeof(ComputerSoftwareProgramTestDataGenerator))]
    public void ComputerSoftwareProgramDeserialize(ComputerSoftwareProgramTestData inComputerSoftwareProgramTestData)
    {
      Fixture.Serializer.Deserialize<ComputerSoftwareProgram>(inComputerSoftwareProgramTestData.SerializedTestData).Should().Be(inComputerSoftwareProgramTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(ComputerSoftwareProgramTestDataGenerator.TestData), MemberType = typeof(ComputerSoftwareProgramTestDataGenerator))]
    public void ComputerSoftwareProgramSerialize(ComputerSoftwareProgramTestData inComputerSoftwareProgramTestData)
    {
      Fixture.Serializer.Serialize(inComputerSoftwareProgramTestData.ObjTestData).Should().Be(inComputerSoftwareProgramTestData.SerializedTestData);
    }

  }
}
