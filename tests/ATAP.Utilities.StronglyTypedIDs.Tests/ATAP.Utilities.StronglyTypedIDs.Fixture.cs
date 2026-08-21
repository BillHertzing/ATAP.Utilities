using System.Text.Json;
using SystemTextJsonSerializer = ATAP.Utilities.Serializer.Shim.SystemTextJson.Serializer;
using SystemTextJsonSerializerOptions = ATAP.Utilities.Serializer.Shim.SystemTextJson.SerializerOptions;
using Xunit;
using Xunit.Abstractions;

namespace ATAP.Utilities.StronglyTypedId.Tests {
  public sealed class Fixture {
    public JsonSerializerOptions JsonSerializerOptions { get; }
    public SystemTextJsonSerializer Serializer { get; }

    public Fixture() {
      JsonSerializerOptions = Startup.CreateSerializerOptions();
      Serializer = new SystemTextJsonSerializer(new SystemTextJsonSerializerOptions(JsonSerializerOptions));
    }
  }

  public partial class GuidIdUnitTests001 : IClassFixture<Fixture> {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public GuidIdUnitTests001(ITestOutputHelper testOutput, Fixture fixture) {
      TestOutput = testOutput;
      Fixture = fixture;
    }
  }

  public partial class IntIdUnitTests001 : IClassFixture<Fixture> {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public IntIdUnitTests001(ITestOutputHelper testOutput, Fixture fixture) {
      TestOutput = testOutput;
      Fixture = fixture;
    }
  }

  public partial class StronglyTypedIdSerializationUnitTests001 : IClassFixture<Fixture> {
    protected Fixture Fixture { get; }

    public StronglyTypedIdSerializationUnitTests001(Fixture fixture) {
      Fixture = fixture;
    }
  }
}
