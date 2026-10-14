using ATAP.Utilities.StronglyTypedId;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.StronglyTypedId.Tests {
  [Trait("Category", "Unit")]
  public partial class GuidIdUnitTests001 {
    [Theory]
    [MemberData(nameof(GuidIdTestDataGenerator.GuidIdTestData), MemberType = typeof(GuidIdTestDataGenerator))]
    public void GuidIdDeserializeFromJson(GuidIdTestData testData) {
      var result = Fixture.Serializer.Deserialize<GuidStronglyTypedId>(testData.SerializedGuidId);

      result.Should().BeOfType<GuidStronglyTypedId>();
      result.Should().Be(testData.GuidId);
    }

    [Theory]
    [MemberData(nameof(GuidIdTestDataGenerator.GuidIdTestData), MemberType = typeof(GuidIdTestDataGenerator))]
    public void GuidIdSerializeToJson(GuidIdTestData testData) {
      var result = Fixture.Serializer.Serialize(testData.GuidId);

      TestOutput.WriteLine("Serialized GuidStronglyTypedId: {0}", result);
      result.Should().Be(testData.SerializedGuidId);
    }
  }
}
