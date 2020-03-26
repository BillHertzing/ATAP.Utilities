using FluentAssertions;
using Xunit;

using ATAP.Utilities.ComputerInventory.Software;

namespace ATAP.Utilities.ComputerInventory.Software.UnitTests
{


  public partial class ComputerInventorySoftwareUnitTests001 : IClassFixture<ComputerInventorySoftwareFixture>
  {
 
    [Theory]
    [MemberData(nameof(ComputerSoftwareProgramSerializationTestDataGenerator.TestData), MemberType = typeof(ComputerSoftwareProgramSerializationTestDataGenerator))]
    public void ComputerSoftwareProgramDeserialize(ComputerSoftwareSerializationProgramTestData inComputerSoftwareProgramTestData)
    {
      Fixture.Serializer.Deserialize<ComputerSoftwareProgram>(inComputerSoftwareProgramTestData.SerializedTestData).Should().Be(inComputerSoftwareProgramTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(ComputerSoftwareProgramSerializationTestDataGenerator.TestData), MemberType = typeof(ComputerSoftwareProgramSerializationTestDataGenerator))]
    public void ComputerSoftwareProgramSerialize(ComputerSoftwareSerializationProgramTestData inComputerSoftwareProgramTestData)
    {
      Fixture.Serializer.Serialize(inComputerSoftwareProgramTestData.ObjTestData).Should().MatchRegex(inComputerSoftwareProgramTestData.SerializedTestData);
    }

  }
}
