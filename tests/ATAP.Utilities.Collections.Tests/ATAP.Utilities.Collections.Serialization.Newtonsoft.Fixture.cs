using System.Linq;
using System.Text.Json;
using ATAP.Utilities.StronglyTypedId;
using ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson;
using Xunit;

namespace ATAP.Utilities.Collection.Tests {
  public sealed class SerializationFixtureWithClonedOptions {
    public JsonSerializerOptions JsonSerializerOptions { get; } = new(Startup.CreateSerializerOptions());
  }

  [Trait("Category", "Unit")]
  public sealed class SerializationOptionsCloneUnitTests : IClassFixture<SerializationFixtureWithClonedOptions> {
    private readonly SerializationFixtureWithClonedOptions fixture;

    public SerializationOptionsCloneUnitTests(SerializationFixtureWithClonedOptions fixture) {
      this.fixture = fixture;
    }

    [Fact]
    public void ClonedOptions_RetainStronglyTypedIdConverterAndBehavior() {
      Assert.Contains(fixture.JsonSerializerOptions.Converters, converter => converter is StronglyTypedIdJsonConverterFactory);
      var value = new GuidStronglyTypedId(System.Guid.Empty);

      var json = JsonSerializer.Serialize(value, fixture.JsonSerializerOptions);
      var roundTrip = JsonSerializer.Deserialize<GuidStronglyTypedId>(json, fixture.JsonSerializerOptions);

      Assert.Equal("\"00000000-0000-0000-0000-000000000000\"", json);
      Assert.Equal(value, roundTrip);
    }
  }
}
