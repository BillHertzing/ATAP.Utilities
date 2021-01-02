using System.Text.Json;

namespace ATAP.Utilities.Serializer {
  public class Serializer : ISerializer {
    private JsonSerializerOptions JsonSerializerOptionsCurrent { get; set; }
    public Serializer() {
      this.Configure();
    }

    public string Serialize(object obj) {
      return JsonSerializer.Serialize(obj, JsonSerializerOptionsCurrent);
    }
    public string Serialize(object obj, ISerializerOptions options) {
      JsonSerializerOptions jsonSerializerOptions = ConvertOptions(options);
      return JsonSerializer.Serialize(obj, jsonSerializerOptions);
    }
    public T Deserialize<T>(string str) {
      return JsonSerializer.Deserialize<T>(str, JsonSerializerOptionsCurrent);
    }
    public T Deserialize<T>(string str, ISerializerOptions options) {
      JsonSerializerOptions jsonSerializerOptions = ConvertOptions(options);
      return JsonSerializer.Deserialize<T>(str, jsonSerializerOptions);
    }

    public void Configure() {
      JsonSerializerOptionsCurrent = new JsonSerializerOptions {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
      };
    }
    public void Configure(ISerializerOptions options) {
      JsonSerializerOptionsCurrent = ConvertOptions(options);
    }
    public void Configure(
        bool allowTrailingCommas = false
      , bool writeIndented = false
      , bool ignoreNullValues = false
    ) {
      JsonSerializerOptionsCurrent = ConvertOptions(allowTrailingCommas, writeIndented, ignoreNullValues);
    }

    private JsonSerializerOptions ConvertOptions(
        bool allowTrailingCommas = false
      , bool ignoreNullValues = false
      , bool writeIndented = false
    ) {
      return new JsonSerializerOptions {
        AllowTrailingCommas = allowTrailingCommas,
        IgnoreNullValues = ignoreNullValues,
        WriteIndented = writeIndented,
      };
    }
    private JsonSerializerOptions ConvertOptions(ISerializerOptions options) {
      return new JsonSerializerOptions {
        AllowTrailingCommas = options.AllowTrailingCommas,
        IgnoreNullValues = options.IgnoreNullValues,
        WriteIndented = options.WriteIndented
      };
    }

  }

  public class SerializerOptions : ISerializerOptions {
    public bool AllowTrailingCommas { get; set; }
    public bool WriteIndented { get; set; }
    public bool IgnoreNullValues { get; set; }
  }
}
