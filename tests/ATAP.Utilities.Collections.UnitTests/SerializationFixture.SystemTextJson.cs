
using System;
using System.Text.Json;

using Xunit.Abstractions;

namespace ATAP.Utilities.Collection.UnitTests {
  // The SerializationFixtureSystemTextJson can only be setup one time, before all tests are run
  //  because JsonSerializerSettings cannot be modified after any Serialization/Deserialization operations have been performed
  public class SerializationFixtureSystemTextJson {
    public JsonSerializerOptions JsonSerializerOptions { get; set; }
    public SerializationFixtureSystemTextJson() {
      JsonSerializerOptions = new JsonSerializerOptions();
      // Add Converters
      JsonSerializerOptions.Converters.Add(new ATAP.Utilities.Collections.JsonConverterSystemTextJson.StronglyTypedIdJsonConverterFactory());
    }
  }

  public partial class StronglyTypedIDSerializationSystemTextJsonUnitTests001 {
    protected SerializationFixtureSystemTextJson SerializationFixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public StronglyTypedIDSerializationSystemTextJsonUnitTests001(ITestOutputHelper testOutput, SerializationFixtureSystemTextJson serializationFixture) {
      SerializationFixture = serializationFixture;
      TestOutput = testOutput;
      if (SerializationFixture == null) { TestOutput.WriteLine("SerializationFixture is null"); }
      if (SerializationFixture.Serializer == null) { TestOutput.WriteLine("SerializationFixture.Serializer is null"); }

      // ToDo: Ensure the System.StringComparison.CurrentCulture is configured properly to match the test data, for String.StartsWith used in the tests
    }
  }
}
