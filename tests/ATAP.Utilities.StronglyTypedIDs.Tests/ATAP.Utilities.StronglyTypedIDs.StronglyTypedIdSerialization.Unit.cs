using System;
using ATAP.Utilities.StronglyTypedId;
using FluentAssertions;
using Xunit;

namespace ATAP.Utilities.StronglyTypedId.Tests {
  [Trait("Category", "Unit")]
  public partial class StronglyTypedIdSerializationUnitTests001 {
    [Theory]
    [MemberData(nameof(GuidStronglyTypedIdSerializationTestDataGenerator.StronglyTypedIdSerializationTestData), MemberType = typeof(GuidStronglyTypedIdSerializationTestDataGenerator))]
    public void GuidIdSerializeToJson(GuidStronglyTypedIdSerializationTestData testData) {
      Fixture.Serializer.Serialize(testData.InstanceTestData).Should().Be(testData.SerializedTestData);
    }

    [Theory]
    [MemberData(nameof(GuidStronglyTypedIdSerializationTestDataGenerator.StronglyTypedIdSerializationTestData), MemberType = typeof(GuidStronglyTypedIdSerializationTestDataGenerator))]
    public void GuidIdDeserializeFromJson(GuidStronglyTypedIdSerializationTestData testData) {
      Fixture.Serializer.Deserialize<GuidStronglyTypedId>(testData.SerializedTestData).Should().Be(testData.InstanceTestData);
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIdInterfaceSerializationTestDataGenerator<Guid>.StronglyTypedIdSerializationTestData), MemberType = typeof(StronglyTypedIdInterfaceSerializationTestDataGenerator<Guid>))]
    public void GuidStronglyTypedIdInterfaceSerializeToJson(StronglyTypedIdInterfaceSerializationTestData<Guid> testData) {
      Fixture.Serializer.Serialize(testData.InstanceTestData).Should().Be(testData.SerializedTestData);
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIdInterfaceSerializationTestDataGenerator<Guid>.StronglyTypedIdSerializationTestData), MemberType = typeof(StronglyTypedIdInterfaceSerializationTestDataGenerator<Guid>))]
    public void GuidStronglyTypedIdInterfaceDeserializeFromJson(StronglyTypedIdInterfaceSerializationTestData<Guid> testData) {
      var result = Fixture.Serializer.Deserialize<IAbstractStronglyTypedId<Guid>>(testData.SerializedTestData);

      result.Should().BeEquivalentTo(testData.InstanceTestData);
      result.Should().BeOfType<GuidStronglyTypedId>();
    }

    [Theory]
    [MemberData(nameof(IntStronglyTypedIdSerializationTestDataGenerator.StronglyTypedIdSerializationTestData), MemberType = typeof(IntStronglyTypedIdSerializationTestDataGenerator))]
    public void IntIdSerializeToJson(IntStronglyTypedIdSerializationTestData testData) {
      Fixture.Serializer.Serialize(testData.InstanceTestData).Should().Be(testData.SerializedTestData);
    }

    [Theory]
    [MemberData(nameof(IntStronglyTypedIdSerializationTestDataGenerator.StronglyTypedIdSerializationTestData), MemberType = typeof(IntStronglyTypedIdSerializationTestDataGenerator))]
    public void IntIdDeserializeFromJson(IntStronglyTypedIdSerializationTestData testData) {
      Fixture.Serializer.Deserialize<IntStronglyTypedId>(testData.SerializedTestData).Should().Be(testData.InstanceTestData);
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIdInterfaceSerializationTestDataGenerator<int>.StronglyTypedIdSerializationTestData), MemberType = typeof(StronglyTypedIdInterfaceSerializationTestDataGenerator<int>))]
    public void IntStronglyTypedIdInterfaceSerializeToJson(StronglyTypedIdInterfaceSerializationTestData<int> testData) {
      Fixture.Serializer.Serialize(testData.InstanceTestData).Should().Be(testData.SerializedTestData);
    }

    [Theory]
    [MemberData(nameof(StronglyTypedIdInterfaceSerializationTestDataGenerator<int>.StronglyTypedIdSerializationTestData), MemberType = typeof(StronglyTypedIdInterfaceSerializationTestDataGenerator<int>))]
    public void IntStronglyTypedIdInterfaceDeserializeFromJson(StronglyTypedIdInterfaceSerializationTestData<int> testData) {
      var result = Fixture.Serializer.Deserialize<IAbstractStronglyTypedId<int>>(testData.SerializedTestData);

      result.Should().BeEquivalentTo(testData.InstanceTestData);
      result.Should().BeOfType<IntStronglyTypedId>();
    }

    [Fact]
    public void GuidIdDeserializeFromEmptyJson_ThrowsJsonException() {
      var act = () => Fixture.Serializer.Deserialize<GuidStronglyTypedId>(string.Empty);

      act.Should().Throw<System.Text.Json.JsonException>();
    }

    [Fact]
    public void IntIdDeserializeFromEmptyJson_ThrowsJsonException() {
      var act = () => Fixture.Serializer.Deserialize<IntStronglyTypedId>(string.Empty);

      act.Should().Throw<System.Text.Json.JsonException>();
    }
  }
}
