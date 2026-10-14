using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using ATAP.Utilities.StronglyTypedId;
using Xunit;

using static ATAP.Utilities.Collection.Extensions;

namespace ATAP.Utilities.Collection.Tests {
  [Trait("Category", "Unit")]
  public partial class StronglyTypedIdSerializationSystemTextJsonUnitTests001 {
    [Theory]
    [MemberData(nameof(GuidStronglyTypedIdSerializationTestDataGenerator.Data), MemberType = typeof(GuidStronglyTypedIdSerializationTestDataGenerator))]
    public void GuidIdSerializeToJson(GuidStronglyTypedIdSerializationTestData testData) {
      var json = JsonSerializer.Serialize(testData.InstanceTestData, SerializationFixture.JsonSerializerOptions);

      Assert.Equal(testData.SerializedTestData, json);
    }

    [Theory]
    [MemberData(nameof(GuidStronglyTypedIdSerializationTestDataGenerator.Data), MemberType = typeof(GuidStronglyTypedIdSerializationTestDataGenerator))]
    public void GuidIdDeserializeFromJson(GuidStronglyTypedIdSerializationTestData testData) {
      var result = JsonSerializer.Deserialize<GuidStronglyTypedId>(testData.SerializedTestData, SerializationFixture.JsonSerializerOptions);

      Assert.Equal(testData.InstanceTestData, result);
    }

    [Theory]
    [MemberData(nameof(CollectionExtensionSerializationTestDataGenerator.GuidData), MemberType = typeof(CollectionExtensionSerializationTestDataGenerator))]
    public void GuidCollectionSerializeToJson(CollectionExtensionSerializationTestData<GuidStronglyTypedId> testData) {
      var json = JsonSerializer.Serialize(testData.InstanceTestData, SerializationFixture.JsonSerializerOptions);

      Assert.Equal(testData.SerializedTestData, json);
    }

    [Theory]
    [MemberData(nameof(CollectionExtensionSerializationTestDataGenerator.GuidData), MemberType = typeof(CollectionExtensionSerializationTestDataGenerator))]
    public void GuidCollectionDeserializeFromJson(CollectionExtensionSerializationTestData<GuidStronglyTypedId> testData) {
      var result = JsonSerializer.Deserialize<List<GuidStronglyTypedId>>(testData.SerializedTestData, SerializationFixture.JsonSerializerOptions);

      Assert.Equal(testData.InstanceTestData, result);
    }

    [Theory]
    [MemberData(nameof(IntStronglyTypedIdSerializationTestDataGenerator.Data), MemberType = typeof(IntStronglyTypedIdSerializationTestDataGenerator))]
    public void IntIdSerializeToJson(IntStronglyTypedIdSerializationTestData testData) {
      var json = JsonSerializer.Serialize(testData.InstanceTestData, SerializationFixture.JsonSerializerOptions);

      Assert.Equal(testData.SerializedTestData, json);
    }

    [Theory]
    [MemberData(nameof(IntStronglyTypedIdSerializationTestDataGenerator.Data), MemberType = typeof(IntStronglyTypedIdSerializationTestDataGenerator))]
    public void IntIdDeserializeFromJson(IntStronglyTypedIdSerializationTestData testData) {
      var result = JsonSerializer.Deserialize<IntStronglyTypedId>(testData.SerializedTestData, SerializationFixture.JsonSerializerOptions);

      Assert.Equal(testData.InstanceTestData, result);
    }

    [Theory]
    [MemberData(nameof(CollectionExtensionSerializationTestDataGenerator.IntData), MemberType = typeof(CollectionExtensionSerializationTestDataGenerator))]
    public void IntCollectionSerializeToJson(CollectionExtensionSerializationTestData<IntStronglyTypedId> testData) {
      var json = JsonSerializer.Serialize(testData.InstanceTestData, SerializationFixture.JsonSerializerOptions);

      Assert.Equal(testData.SerializedTestData, json);
    }

    [Theory]
    [MemberData(nameof(CollectionExtensionSerializationTestDataGenerator.IntData), MemberType = typeof(CollectionExtensionSerializationTestDataGenerator))]
    public void IntCollectionDeserializeFromJson(CollectionExtensionSerializationTestData<IntStronglyTypedId> testData) {
      var result = JsonSerializer.Deserialize<List<IntStronglyTypedId>>(testData.SerializedTestData, SerializationFixture.JsonSerializerOptions);

      Assert.Equal(testData.InstanceTestData, result);
    }

    [Fact]
    public void GuidIdDeserializeFromEmptyJson_ThrowsJsonException() {
      Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<GuidStronglyTypedId>(string.Empty, SerializationFixture.JsonSerializerOptions));
    }

    [Fact]
    public void IntIdDeserializeFromEmptyJson_ThrowsJsonException() {
      Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<IntStronglyTypedId>(string.Empty, SerializationFixture.JsonSerializerOptions));
    }
  }

  [Trait("Category", "Unit")]
  public class CollectionExtensionUnitTests {
    [Fact]
    public void Merge_DisjointDictionaries_ReturnsAllEntries() {
      var dictionaries = new[] {
        new Dictionary<string, int> { ["alpha"] = 1 },
        new Dictionary<string, int> { ["beta"] = 2 },
      };

      var result = Merge(dictionaries);

      Assert.Equal(2, result.Count);
      Assert.Equal(1, result["alpha"]);
      Assert.Equal(2, result["beta"]);
    }

    [Fact]
    public void HasSingle_SingleItem_ReturnsTrueAndItem() {
      var sequence = new[] { 42 };

      var result = sequence.HasSingle(out var value);

      Assert.True(result);
      Assert.Equal(42, value);
    }

    [Fact]
    public void DistinctBy_RepeatedKey_KeepsFirstItem() {
      var values = new[] { "alpha", "atom", "beta" };

      var result = ATAP.Utilities.Collection.Extensions.DistinctBy(values, value => value[0]).ToArray();

      Assert.Equal(new[] { "alpha", "beta" }, result);
    }
  }
}
