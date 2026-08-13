using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.DateTime.StringConstants;

namespace ATAP.Utilities.DateTime.Model;

internal sealed class TemporalValidityPeriodJsonConverter : JsonConverter<TemporalValidityPeriod>
{
  public override bool HandleNull => true;

  public override TemporalValidityPeriod Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
  {
    if (reader.TokenType != JsonTokenType.StartObject)
    {
      throw new JsonException("A temporal validity period must be a JSON object.");
    }

    UtcInstant validFromUtc = default;
    UtcInstant? validToUtc = null;
    var hasValidFromUtc = false;
    var hasValidToUtc = false;

    while (reader.Read() && reader.TokenType != JsonTokenType.EndObject)
    {
      if (reader.TokenType != JsonTokenType.PropertyName)
      {
        throw new JsonException("A temporal validity period contains an invalid JSON token.");
      }

      if (reader.ValueTextEquals(TemporalJsonPropertyNames.ValidFromUtc) && !hasValidFromUtc)
      {
        if (!reader.Read() || reader.TokenType == JsonTokenType.Null)
        {
          throw new JsonException("validFromUtc must be a UTC instant.");
        }

        validFromUtc = JsonSerializer.Deserialize<UtcInstant>(ref reader, options);
        hasValidFromUtc = true;
      }
      else if (reader.ValueTextEquals(TemporalJsonPropertyNames.ValidToUtc) && !hasValidToUtc)
      {
        if (!reader.Read())
        {
          throw new JsonException("validToUtc must be a UTC instant or null.");
        }

        validToUtc = reader.TokenType == JsonTokenType.Null
          ? null
          : JsonSerializer.Deserialize<UtcInstant>(ref reader, options);
        hasValidToUtc = true;
      }
      else
      {
        throw new JsonException("A temporal validity period must contain only validFromUtc and validToUtc.");
      }
    }

    if (reader.TokenType != JsonTokenType.EndObject || !hasValidFromUtc || !hasValidToUtc)
    {
      throw new JsonException("A temporal validity period requires validFromUtc and validToUtc.");
    }

    try
    {
      return new TemporalValidityPeriod(validFromUtc, validToUtc);
    }
    catch (ArgumentException exception)
    {
      throw new JsonException("The temporal validity period boundaries are invalid.", exception);
    }
  }

  public override void Write(Utf8JsonWriter writer, TemporalValidityPeriod value, JsonSerializerOptions options)
  {
    if (value is null)
    {
      throw new JsonException("A temporal validity period cannot be null.");
    }

    writer.WriteStartObject();
    writer.WritePropertyName(TemporalJsonPropertyNames.ValidFromUtc);
    JsonSerializer.Serialize(writer, value.ValidFromUtc, options);
    writer.WritePropertyName(TemporalJsonPropertyNames.ValidToUtc);
    if (value.ValidToUtc is { } validToUtc)
    {
      JsonSerializer.Serialize(writer, validToUtc, options);
    }
    else
    {
      writer.WriteNullValue();
    }

    writer.WriteEndObject();
  }
}
