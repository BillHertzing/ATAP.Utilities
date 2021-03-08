using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Collections.Concurrent;

// For the NotNullWhenAttribute used in code
using System.Diagnostics.CodeAnalysis;

using ATAP.Utilities.StronglyTypedID;

namespace ATAP.Utilities.StronglyTypedID.JsonConverter.SystemTextJson {
  // Attribution https://thomaslevesque.com/2020/12/07/csharp-9-records-as-strongly-typed-ids-part-3-json-serialization/

  public class StronglyTypedIDJsonConverter<TStronglyTypedID, TValue> : JsonConverter<TStronglyTypedID>
      where TStronglyTypedID : IStronglyTypedID<TValue>
      where TValue : notnull {
    public override TStronglyTypedID Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) {
      if (reader.TokenType is JsonTokenType.Null) {
        return default;
      }

      var value = JsonSerializer.Deserialize<TValue>(ref reader, options);
      var factory = StronglyTypedID.StronglyTypedIDHelper.GetFactory<TValue>(typeToConvert);
      return (TStronglyTypedID)factory(value);
    }

    public override void Write(Utf8JsonWriter writer, TStronglyTypedID value, JsonSerializerOptions options) {
      if (value is null) {
        writer.WriteNullValue();
      }
      else {
        JsonSerializer.Serialize(writer, value.Value, options);
      }
    }
  }

  public class StronglyTypedIDJsonConverterFactory : JsonConverterFactory {
    private static readonly ConcurrentDictionary<Type, System.Text.Json.Serialization.JsonConverter> Cache = new();

    public override bool CanConvert(Type typeToConvert) {
      return StronglyTypedIDHelper.IsStronglyTypedID(typeToConvert);
    }

    public override System.Text.Json.Serialization.JsonConverter CreateConverter(Type typeToConvert, JsonSerializerOptions options) {
      return Cache.GetOrAdd(typeToConvert, CreateConverter);
    }

    private static System.Text.Json.Serialization.JsonConverter CreateConverter(Type typeToConvert) {
      if (!StronglyTypedIDHelper.IsStronglyTypedID(typeToConvert, out var valueType)) {
        throw new InvalidOperationException($"Cannot create converter for '{typeToConvert}'");
      }

      var type = typeof(StronglyTypedIDJsonConverter<,>).MakeGenericType(typeToConvert, valueType);
      return (System.Text.Json.Serialization.JsonConverter)Activator.CreateInstance(type);
    }
  }

  /*
      public class ResultConverter<T> : JsonConverter {
      public override bool CanWrite => false;
      public override bool CanRead => true;
      public override bool CanConvert(Type objectType) {
          return objectType==typeof(IdAsStruct<T>);
      }

      public override object ReadJson(JsonReader reader, Type objectType, object existingValue, JsonSerializer serializer) {
          var jsonObject = JObject.Load(reader);

if(System.Diagnostics.Debugger.IsAttached)
System.Diagnostics.Debugger.Break();
          IdAsStruct<T> result = new IdAsStruct<T> {
              //_value=jsonObject["_value"].Value();

          };
          return result;
      }


      public override void WriteJson(JsonWriter writer, object value, JsonSerializer serializer) {
          throw new InvalidOperationException("Use default serialization.");
      }
  }
  */

}
