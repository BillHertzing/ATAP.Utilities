using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Numerics;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ATAP.Utilities.Serializer.Shim.SystemTextJson {
  //Attribution: https://github.com/TheBuzzSaw/KellySharp/blob/master/KellySharp/DictionaryJsonConverter/IDictionaryJsonConverter.cs
  public class IDictionaryJsonConverter<TKey, TValue> :
      JsonConverter<IDictionary<TKey, TValue>?> where TKey : notnull {
    private readonly Converter<string?, TKey> _keyParser;
    private readonly Converter<TKey, string> _keySerializer;

    public IDictionaryJsonConverter(
        Converter<string?, TKey> keyParser,
        Converter<TKey, string> keySerializer) {
      _keyParser = keyParser;
      _keySerializer = keySerializer;
    }

    public override IDictionary<TKey, TValue>? Read(
        ref Utf8JsonReader reader,
        Type typeToConvert,
        JsonSerializerOptions options) {
      return DictionaryJsonConverter<TKey, TValue>.Read(
          ref reader, _keyParser, options);
    }

    public override void Write(
        Utf8JsonWriter writer,
        IDictionary<TKey, TValue>? value,
        JsonSerializerOptions options) {
      if (value is null) {
        writer.WriteNullValue();
      }
      else {
        writer.WriteStartObject();

        foreach (var pair in value) {
          writer.WritePropertyName(_keySerializer(pair.Key));
          JsonSerializer.Serialize(writer, pair.Value, options);
        }

        writer.WriteEndObject();
      }
    }
  }
}
