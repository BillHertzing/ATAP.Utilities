using ATAP.Utilities.StronglyTypedId;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.StronglyTypedId.Tests {
  [Trait("Category", "Unit")]
  public partial class IntIdUnitTests001 {
    [Theory]
    [MemberData(nameof(IntIdTestDataGenerator.IntIdTestData), MemberType = typeof(IntIdTestDataGenerator))]
    public void IntIdDeserializeFromJson(IntIdTestData testData) {
      var result = Fixture.Serializer.Deserialize<IntStronglyTypedId>(testData.SerializedIntId);

      result.Should().BeOfType<IntStronglyTypedId>();
      result.Should().Be(testData.IntId);
    }

    [Theory]
    [MemberData(nameof(IntIdTestDataGenerator.IntIdTestData), MemberType = typeof(IntIdTestDataGenerator))]
    public void IntIdSerializeToJson(IntIdTestData testData) {
      var result = Fixture.Serializer.Serialize(testData.IntId);

      TestOutput.WriteLine("Serialized IntStronglyTypedId: {0}", result);
      result.Should().Be(testData.SerializedIntId);
    }
  }
}
