using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Numerics;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ATAP.Utilities.Serializer.Shim.SystemTextJson
{
  // Attribution: https://raw.githubusercontent.com/TheBuzzSaw/KellySharp/master/KellySharp/DictionaryJsonConverter/SortedDictionaryJsonConverter.cs
    public class SortedDictionaryJsonConverter<TKey, TValue> :
        JsonConverter<SortedDictionary<TKey, TValue>?> where TKey : notnull
    {
        private readonly Converter<string, TKey> _keyParser;
        private readonly Converter<TKey, string> _keySerializer;

        public SortedDictionaryJsonConverter(
            Converter<string, TKey> keyParser,
            Converter<TKey, string> keySerializer)
        {
            _keyParser = keyParser;
            _keySerializer = keySerializer;
        }

        public override SortedDictionary<TKey, TValue>? Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.Null)
                return null;

            if (reader.TokenType != JsonTokenType.StartObject)
                throw new JsonException("Dictionary must be JSON object.");

            var result = new SortedDictionary<TKey, TValue>();

            while (true)
            {
                if (!reader.Read())
                    throw new JsonException("Incomplete JSON object");

                if (reader.TokenType == JsonTokenType.EndObject)
                    return result;

                var key = _keyParser(reader.GetString() ?? string.Empty);

                if (!reader.Read())
                    throw new JsonException("Incomplete JSON object");

                var value = JsonSerializer.Deserialize<TValue>(ref reader, options);
                result.Add(key, value);
            }
        }

        public override void Write(
            Utf8JsonWriter writer,
            SortedDictionary<TKey, TValue>? value,
            JsonSerializerOptions options)
        {
            if (value is null)
            {
                writer.WriteNullValue();
            }
            else
            {
                writer.WriteStartObject();

                foreach (var pair in value)
                {
                    writer.WritePropertyName(_keySerializer(pair.Key));
                    JsonSerializer.Serialize(writer, pair.Value, options);
                }

                writer.WriteEndObject();
            }
        }
    }
}
