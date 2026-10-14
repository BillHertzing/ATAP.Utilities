

using System;
using ATAP.Utilities.Testing;
using ATAP.Utilities.ComputerInventory.Software;
using System.Text.Json.Serialization;
using ATAP.Utilities.Serializer;
using Microsoft.Extensions.Configuration;
using System.Text.Json;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;


namespace ATAP.Utilities.ComputerInventory.Software.Tests
{
  public class Fixture : SimpleFixture
  {
    public ISerializerConfigurableAbstract Serializer { get; } = new SystemTextJsonTestSerializer();
  }

  internal sealed class SystemTextJsonTestSerializer : ISerializerConfigurableAbstract
  {
    private sealed class OptionsAdapter : ISerializerOptionsAbstract
    {
      public OptionsAdapter()
      {
        var options = new JsonSerializerOptions();
        options.Converters.Add(new ComputerSoftwareProgramConverter());
        ShimSpecificOptions = options;
      }

      public object ShimSpecificOptions { get; set; }
    }

    public IConfigurationRoot? ConfigurationRoot { get; set; }
    public ISerializerOptionsAbstract Options { get; set; } = new OptionsAdapter();

    public string Serialize(object obj) => Serialize(obj, Options);

    public string Serialize(object obj, ISerializerOptionsAbstract options) =>
      JsonSerializer.Serialize(obj, obj.GetType(), GetOptions(options));

    public T Deserialize<T>(string str) => Deserialize<T>(str, Options);

    public T Deserialize<T>(string str, ISerializerOptionsAbstract options) =>
      JsonSerializer.Deserialize<T>(str, GetOptions(options))
      ?? throw new JsonException($"Unable to deserialize {typeof(T).FullName}.");

    private static JsonSerializerOptions GetOptions(ISerializerOptionsAbstract options) =>
      options.ShimSpecificOptions as JsonSerializerOptions
      ?? throw new ArgumentException("Expected JsonSerializerOptions.", nameof(options));
  }
  internal sealed class ComputerSoftwareProgramConverter : JsonConverter<ComputerSoftwareProgram>
  {
    public override ComputerSoftwareProgram Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
      using var document = JsonDocument.ParseValue(ref reader);
      var signil = document.RootElement.GetProperty("ComputerSoftwareProgramSignil")
        .Deserialize<ComputerSoftwareProgramSignil>(options)
        ?? throw new JsonException("ComputerSoftwareProgramSignil was null.");
      return new ComputerSoftwareProgram(signil);
    }

    public override void Write(Utf8JsonWriter writer, ComputerSoftwareProgram value, JsonSerializerOptions options)
    {
      writer.WriteStartObject();
      writer.WritePropertyName("ComputerSoftwareProgramSignil");
      JsonSerializer.Serialize(writer, value.ComputerSoftwareProgramSignil, options);
      writer.WriteEndObject();
    }
  }
  public partial class ComputerInventorySoftwareUnitTests001 : IClassFixture<Fixture>
  {
    protected Fixture Fixture { get; }
    protected ITestOutputHelper TestOutput { get; }

    public ComputerInventorySoftwareUnitTests001(ITestOutputHelper testOutput, Fixture fixture)
    {
      Fixture = fixture;
      TestOutput = testOutput;
    }



  }
}
