using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using ATAP.Utilities.DateTime.StringConstants;

namespace ATAP.Utilities.DateTime.Interfaces;

internal sealed class TemporalDurationJsonConverter : JsonConverter<TemporalDuration>
{
  public override TemporalDuration Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
  {
    if (reader.TokenType != JsonTokenType.StartObject)
    {
      throw new JsonException("A temporal duration must be a JSON object.");
    }

    long ticks = 0;
    var hasTicks = false;

    while (reader.Read() && reader.TokenType != JsonTokenType.EndObject)
    {
      if (reader.TokenType != JsonTokenType.PropertyName
        || !reader.ValueTextEquals(TemporalJsonPropertyNames.Ticks)
        || hasTicks)
      {
        throw new JsonException("A temporal duration must contain exactly one ticks property.");
      }

      if (!reader.Read()
        || reader.TokenType != JsonTokenType.Number
        || !reader.TryGetInt64(out ticks)
        || ticks < 0)
      {
        throw new JsonException("Temporal duration ticks must be a non-negative JSON integer.");
      }

      hasTicks = true;
    }

    if (reader.TokenType != JsonTokenType.EndObject || !hasTicks)
    {
      throw new JsonException("A temporal duration must contain exactly one ticks property.");
    }

    return new TemporalDuration(TimeSpan.FromTicks(ticks));
  }

  public override void Write(Utf8JsonWriter writer, TemporalDuration value, JsonSerializerOptions options)
  {
    writer.WriteStartObject();
    writer.WriteNumber(TemporalJsonPropertyNames.Ticks, value.Ticks);
    writer.WriteEndObject();
  }
}
