using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using ATAP.Utilities.DateTime.Model;
using ATAP.Utilities.DateTime.StringConstants;
using ATAP.Utilities.StronglyTypedId;

namespace ATAP.Utilities.Philote.JsonConverter.Shim.SystemTextJson;

public sealed class PhiloteConverterFactory : JsonConverterFactory
{
  private static readonly ConcurrentDictionary<Type, System.Text.Json.Serialization.JsonConverter> Cache = new();

  public override bool CanConvert(Type typeToConvert) =>
    !typeToConvert.IsAbstract && FindPhiloteInterface(typeToConvert) is not null;

  public override System.Text.Json.Serialization.JsonConverter CreateConverter(
    Type typeToConvert,
    JsonSerializerOptions options)
  {
    ArgumentNullException.ThrowIfNull(typeToConvert);
    ArgumentNullException.ThrowIfNull(options);
    return Cache.GetOrAdd(typeToConvert, CreateConverterCore);
  }

  private static System.Text.Json.Serialization.JsonConverter CreateConverterCore(Type typeToConvert)
  {
    var philoteInterface = FindPhiloteInterface(typeToConvert)
      ?? throw new InvalidOperationException($"Cannot create a Philote converter for '{typeToConvert}'.");
    var arguments = philoteInterface.GetGenericArguments();
    var converterType = typeof(PhiloteJsonConverter<,,>).MakeGenericType(
      typeToConvert,
      arguments[0],
      arguments[1]);
    return (System.Text.Json.Serialization.JsonConverter)Activator.CreateInstance(converterType)!;
  }

  private static Type? FindPhiloteInterface(Type type) =>
    type.GetInterfaces().SingleOrDefault(candidate =>
      candidate.IsGenericType
      && candidate.GetGenericTypeDefinition() == typeof(IAbstractPhilote<,>));
}

internal sealed class PhiloteJsonConverter<TPhilote, TId, TValue> : JsonConverter<TPhilote>
  where TPhilote : class, IAbstractPhilote<TId, TValue>
  where TId : AbstractStronglyTypedId<TValue>, new()
  where TValue : notnull
{
  private static readonly string[] LegacyPropertyNames =
  {
    "timeBlocks",
    "isAnytime",
    "isMoment",
    "start",
    "end",
    "duration",
    "durationDescription"
  };

  public override TPhilote Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
  {
    if (reader.TokenType == JsonTokenType.Null)
    {
      throw new JsonException("A Philote value cannot be null.");
    }

    using var document = JsonDocument.ParseValue(ref reader);
    if (document.RootElement.ValueKind != JsonValueKind.Object)
    {
      throw new JsonException("A Philote value must be a JSON object.");
    }

    TId? id = null;
    var additionalIds = new Dictionary<string, IAbstractStronglyTypedId<TValue>>(StringComparer.Ordinal);
    var validityPeriods = TemporalValidityPeriodSet.Empty;
    var sawId = false;
    var sawAdditionalIds = false;
    var sawValidityPeriods = false;

    foreach (var property in document.RootElement.EnumerateObject())
    {
      if (LegacyPropertyNames.Any(name => string.Equals(name, property.Name, StringComparison.OrdinalIgnoreCase)))
      {
        throw new JsonException($"Legacy temporal property '{property.Name}' is not supported.");
      }

      switch (property.Name)
      {
        case TemporalJsonPropertyNames.Id:
          EnsureNotDuplicate(ref sawId, property.Name);
          if (property.Value.ValueKind == JsonValueKind.Null)
          {
            throw new JsonException("The Philote id cannot be null.");
          }
          var idValue = JsonSerializer.Deserialize<TValue>(property.Value.GetRawText(), options)
            ?? throw new JsonException("The Philote id could not be read.");
          id = CreateId(idValue);
          break;

        case TemporalJsonPropertyNames.AdditionalIds:
          EnsureNotDuplicate(ref sawAdditionalIds, property.Name);
          ReadAdditionalIds(property.Value, additionalIds, options);
          break;

        case TemporalJsonPropertyNames.ValidityPeriods:
          EnsureNotDuplicate(ref sawValidityPeriods, property.Name);
          validityPeriods = property.Value.ValueKind == JsonValueKind.Null
            ? TemporalValidityPeriodSet.Empty
            : JsonSerializer.Deserialize<TemporalValidityPeriodSet>(property.Value.GetRawText(), options)
              ?? TemporalValidityPeriodSet.Empty;
          break;
      }
    }

    if (!sawId || id is null)
    {
      throw new JsonException("The Philote id property is required.");
    }

    try
    {
      return (TPhilote)(Activator.CreateInstance(
        typeToConvert,
        id,
        additionalIds,
        validityPeriods)
        ?? throw new JsonException($"Could not create '{typeToConvert}'."));
    }
    catch (Exception exception) when (exception is not JsonException)
    {
      throw new JsonException($"Could not create '{typeToConvert}'.", exception);
    }
  }

  public override void Write(Utf8JsonWriter writer, TPhilote value, JsonSerializerOptions options)
  {
    ArgumentNullException.ThrowIfNull(writer);
    ArgumentNullException.ThrowIfNull(value);
    ArgumentNullException.ThrowIfNull(options);

    writer.WriteStartObject();
    writer.WritePropertyName(TemporalJsonPropertyNames.Id);
    JsonSerializer.Serialize(writer, value.Id.Value, options);

    writer.WritePropertyName(TemporalJsonPropertyNames.AdditionalIds);
    writer.WriteStartObject();
    foreach (var pair in value.AdditionalIds.OrderBy(pair => pair.Key, StringComparer.Ordinal))
    {
      writer.WritePropertyName(pair.Key);
      JsonSerializer.Serialize(writer, pair.Value.Value, options);
    }
    writer.WriteEndObject();

    writer.WritePropertyName(TemporalJsonPropertyNames.ValidityPeriods);
    JsonSerializer.Serialize(writer, new TemporalValidityPeriodSet(value.ValidityPeriods), options);
    writer.WriteEndObject();
  }

  private static void ReadAdditionalIds(
    JsonElement element,
    IDictionary<string, IAbstractStronglyTypedId<TValue>> destination,
    JsonSerializerOptions options)
  {
    if (element.ValueKind == JsonValueKind.Null)
    {
      return;
    }

    if (element.ValueKind != JsonValueKind.Object)
    {
      throw new JsonException("The additionalIds property must be an object or null.");
    }

    foreach (var property in element.EnumerateObject())
    {
      if (property.Value.ValueKind == JsonValueKind.Null)
      {
        throw new JsonException("An additional ID cannot be null.");
      }

      var value = JsonSerializer.Deserialize<TValue>(property.Value.GetRawText(), options)
        ?? throw new JsonException("An additional ID could not be read.");
      var stronglyTypedId = CreateId(value);
      if (!destination.TryAdd(property.Name, stronglyTypedId))
      {
        throw new JsonException($"Duplicate additional ID '{property.Name}'.");
      }
    }
  }

  private static void EnsureNotDuplicate(ref bool seen, string propertyName)
  {
    if (seen)
    {
      throw new JsonException($"Duplicate property '{propertyName}'.");
    }
    seen = true;
  }

  private static TId CreateId(TValue value)
  {
    try
    {
      return (TId)(Activator.CreateInstance(typeof(TId), value)
        ?? throw new JsonException($"Could not create '{typeof(TId)}'."));
    }
    catch (Exception exception) when (exception is not JsonException)
    {
      throw new JsonException($"Could not create '{typeof(TId)}'.", exception);
    }
  }
}
