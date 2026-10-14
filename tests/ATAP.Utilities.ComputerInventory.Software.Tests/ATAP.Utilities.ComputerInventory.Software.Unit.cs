using FluentAssertions;
using System.Text.Json.Nodes;
using Xunit;

using ATAP.Utilities.ComputerInventory.Software;

namespace ATAP.Utilities.ComputerInventory.Software.Tests
{


  [Trait("Category", "Unit")]
  public partial class ComputerInventorySoftwareUnitTests001 : IClassFixture<Fixture>
  {

    [Theory]
    [MemberData(nameof(ComputerSoftwareProgramSerializationTestDataGenerator.TestData), MemberType = typeof(ComputerSoftwareProgramSerializationTestDataGenerator))]
    public void ComputerSoftwareProgramDeserialize(ComputerSoftwareSerializationProgramTestData inComputerSoftwareProgramTestData)
    {
      Fixture.Serializer.Deserialize<ComputerSoftwareProgram>(inComputerSoftwareProgramTestData.SerializedTestData).Should().BeEquivalentTo(inComputerSoftwareProgramTestData.ObjTestData);
    }

    [Theory]
    [MemberData(nameof(ComputerSoftwareProgramSerializationTestDataGenerator.TestData), MemberType = typeof(ComputerSoftwareProgramSerializationTestDataGenerator))]
    public void ComputerSoftwareProgramSerialize(ComputerSoftwareSerializationProgramTestData inComputerSoftwareProgramTestData)
    {
      var actualJson = JsonNode.Parse(Fixture.Serializer.Serialize(inComputerSoftwareProgramTestData.ObjTestData));
      var expectedJson = JsonNode.Parse(inComputerSoftwareProgramTestData.SerializedTestData);

      JsonNode.DeepEquals(actualJson, expectedJson).Should().BeTrue();
    }

  }
}
