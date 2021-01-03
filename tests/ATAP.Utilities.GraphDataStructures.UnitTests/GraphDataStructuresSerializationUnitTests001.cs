

using ATAP.Utilities.GraphDataStructures;
using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.GraphDataStructures.UnitTests
{
  public partial class GraphDataStructuresUnitTests001 : IClassFixture<GraphDataStructuresFixture>
  {
    [Theory]
    [MemberData(nameof(GraphDataStructuresSerializationTestDataGenerator.TestData), MemberType = typeof(GraphDataStructuresSerializationTestDataGenerator))]
    public void GraphDataStructuresDeserializeFromJSON(SerializationTestData inTestData)
    {
      var obj = Fixture.Serializer.Deserialize<UnitsNet.Information>(inTestData.SerializedTestData);
      obj.Should().BeOfType(typeof(UnitsNet.Information));
      Fixture.Serializer.Deserialize<UnitsNet.Information>(inTestData.SerializedTestData).Should().BeEquivalentTo(inTestData.ObjTestData);
    }
    [Theory]
    [MemberData(nameof(GraphDataStructuresSerializationTestDataGenerator.TestData), MemberType = typeof(GraphDataStructuresSerializationTestDataGenerator))]
    public void GraphDataStructuresSerializeToJSON(SerializationTestData inTestData)
    {
      Fixture.Serializer.Serialize(inTestData.ObjTestData).Should().Be(inTestData.SerializedTestData);
    }
    }
}
