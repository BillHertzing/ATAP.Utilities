using System.Text.Json;
using Xunit;

namespace ATAP.Utilities.Collection.Tests {
  public sealed class SerializationFixtureSystemTextJson {
    public JsonSerializerOptions JsonSerializerOptions { get; } = Startup.CreateSerializerOptions();
  }

  public partial class StronglyTypedIdSerializationSystemTextJsonUnitTests001 : IClassFixture<SerializationFixtureSystemTextJson> {
    protected SerializationFixtureSystemTextJson SerializationFixture { get; }

    public StronglyTypedIdSerializationSystemTextJsonUnitTests001(SerializationFixtureSystemTextJson serializationFixture) {
      SerializationFixture = serializationFixture;
    }
  }
}
