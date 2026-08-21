
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

using ATAP.Utilities.Testing;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.Serializer.Tests
{
  internal sealed class UnitsNetInformationJsonConverter : JsonConverter<UnitsNet.Information>
  {
    public override UnitsNet.Information Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
      if (reader.TokenType != JsonTokenType.String)
      {
        throw new JsonException($"Expected a JSON string for {nameof(UnitsNet.Information)}.");
      }

      var value = reader.GetString();
      if (string.IsNullOrWhiteSpace(value))
      {
        throw new JsonException($"A non-empty {nameof(UnitsNet.Information)} value is required.");
      }

      return UnitsNet.Information.Parse(value, CultureInfo.InvariantCulture);
    }

    public override void Write(Utf8JsonWriter writer, UnitsNet.Information value, JsonSerializerOptions options)
    {
      writer.WriteStringValue(value.ToString(CultureInfo.InvariantCulture));
    }
  }

  public class Fixture : ATAP.Utilities.Testing.Fixture.Serialization.SerializationFixtureSystemTextJson
  {
    public Fixture()
    {
      Serializer = new ATAP.Utilities.Serializer.Shim.SystemTextJson.Serializer(
        new List<JsonConverter> { new UnitsNetInformationJsonConverter() });
    }
  }
  public partial class UnitTests001 : IClassFixture<Fixture >
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }
    public UnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }
  }
}
