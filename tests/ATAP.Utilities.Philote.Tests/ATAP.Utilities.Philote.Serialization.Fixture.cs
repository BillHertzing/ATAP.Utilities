using System.Text.Json;
using ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson;

namespace ATAP.Utilities.Philote.Tests;

public sealed class Fixture
{
  public JsonSerializerOptions SerializerOptions { get; } = CreateOptions();

  private static JsonSerializerOptions CreateOptions()
  {
    var options = new JsonSerializerOptions();
    options.Converters.Add(new PhiloteConverterFactory());
    return options;
  }
}
