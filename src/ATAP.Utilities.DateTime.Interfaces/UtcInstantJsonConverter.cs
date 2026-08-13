using System;
using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ATAP.Utilities.DateTime.Interfaces;

internal sealed class UtcInstantJsonConverter : JsonConverter<UtcInstant>
{
  private const string CanonicalFormat = "yyyy-MM-dd'T'HH:mm:ss.fffffff'Z'";
  private const string ZeroOffsetFormat = "yyyy-MM-dd'T'HH:mm:ss.fffffffzzz";

  public override UtcInstant Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
  {
    if (reader.TokenType != JsonTokenType.String)
    {
      throw new JsonException("A UTC instant must be a JSON string.");
    }

    var text = reader.GetString();
    if (text is null || !HasAcceptedShape(text))
    {
      throw new JsonException("A UTC instant must have exactly seven fractional digits and a zero UTC offset.");
    }

    var format = text.EndsWith('Z') ? CanonicalFormat : ZeroOffsetFormat;
    var styles = text.EndsWith('Z')
      ? DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal
      : DateTimeStyles.None;

    if (!DateTimeOffset.TryParseExact(text, format, CultureInfo.InvariantCulture, styles, out var value)
      || value.Offset != TimeSpan.Zero)
    {
      throw new JsonException("The UTC instant is invalid.");
    }

    return new UtcInstant(value);
  }

  public override void Write(Utf8JsonWriter writer, UtcInstant value, JsonSerializerOptions options) =>
    writer.WriteStringValue(value.Value.ToString(CanonicalFormat, CultureInfo.InvariantCulture));

  private static bool HasAcceptedShape(string text)
  {
    if (text.Length == 28 && text[^1] == 'Z')
    {
      return HasTimestampPunctuation(text);
    }

    return text.Length == 33
      && (text.EndsWith("+00:00", StringComparison.Ordinal) || text.EndsWith("-00:00", StringComparison.Ordinal))
      && HasTimestampPunctuation(text);
  }

  private static bool HasTimestampPunctuation(string text) =>
    text[4] == '-'
    && text[7] == '-'
    && text[10] == 'T'
    && text[13] == ':'
    && text[16] == ':'
    && text[19] == '.';
}
