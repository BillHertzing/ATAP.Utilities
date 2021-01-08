using System;
using System.Collections;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;
using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Serializer.Shim.SystemTextJson {
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
        Converters = {
          new TypedGuidsConverter()
        }

      };
    }
    public void Configure(ISerializerOptions options) {
      JsonSerializerOptionsCurrent = ConvertOptions(options);
    }
    public void Configure(
        bool allowTrailingCommas = false
      , bool writeIndented = false
      , bool ignoreNullValues = false
      , IList<ISerializerConverterAbstract<T>>? Converters
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

 public class TypedGuidsConverter
        : JsonConverter<Id<T>>
    {
        public override object Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options) => reader.TokenType switch
            {
                JsonTokenType.True => true,
                JsonTokenType.False => false,
                JsonTokenType.Number when reader.TryGetInt64(out long l) => l,
                JsonTokenType.Number => reader.GetDouble(),
                JsonTokenType.String when reader.TryGetDateTime(out DateTime datetime) => datetime,
                JsonTokenType.String => reader.GetString(),
                _ => JsonDocument.ParseValue(ref reader).RootElement.Clone()
            };

        public override void Write(
            Utf8JsonWriter writer,
            object objectToWrite,
            JsonSerializerOptions options) =>
            throw new InvalidOperationException("Should not get here.");
    }

  public abstract class SerializerConverterFactory<T> {
    public abstract bool CanConvert(Type typeToConvert);
    public abstract JsonConverter<T> CreateConverter(
                Type type,
                JsonSerializerOptions options);
  }

  public abstract class SerializerConverter<T> : JsonConverter<T> {

  }

}
