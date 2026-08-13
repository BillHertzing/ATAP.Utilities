using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ATAP.Utilities.DateTime.Model;

internal sealed class TemporalValidityPeriodSetJsonConverter : JsonConverter<TemporalValidityPeriodSet>
{
  public override bool HandleNull => true;

  public override TemporalValidityPeriodSet Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
  {
    if (reader.TokenType != JsonTokenType.StartArray)
    {
      throw new JsonException("A temporal validity period set must be a JSON array.");
    }

    var periods = new List<TemporalValidityPeriod>();
    while (reader.Read() && reader.TokenType != JsonTokenType.EndArray)
    {
      if (reader.TokenType == JsonTokenType.Null)
      {
        throw new JsonException("A temporal validity period set cannot contain a null element.");
      }

      var period = JsonSerializer.Deserialize<TemporalValidityPeriod>(ref reader, options);
      if (period is null)
      {
        throw new JsonException("A temporal validity period set cannot contain a null element.");
      }

      periods.Add(period);
    }

    if (reader.TokenType != JsonTokenType.EndArray)
    {
      throw new JsonException("The temporal validity period set is incomplete.");
    }

    try
    {
      return new TemporalValidityPeriodSet(periods);
    }
    catch (ArgumentException exception)
    {
      throw new JsonException("The temporal validity period set is invalid.", exception);
    }
  }

  public override void Write(Utf8JsonWriter writer, TemporalValidityPeriodSet value, JsonSerializerOptions options)
  {
    if (value is null)
    {
      throw new JsonException("A temporal validity period set cannot be null.");
    }

    writer.WriteStartArray();
    foreach (var period in value)
    {
      JsonSerializer.Serialize(writer, period, options);
    }

    writer.WriteEndArray();
  }
}
