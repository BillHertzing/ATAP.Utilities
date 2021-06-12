using System;
using System.Collections.Concurrent;
using System.Text.Json;
using System.Text.Json.Serialization;

using ATAP.Utilities.StronglyTypedIds;

namespace ATAP.Utilities.StronglyTypedIds.JsonConverter.Shim.SystemTextJson {
  // Attribution https://thomaslevesque.com/2020/12/07/csharp-9-records-as-strongly-typed-ids-part-3-json-serialization/

  // An individual converter for a specific instance of the AbstractStronglyTypedId record type
  public class StronglyTypedIdJsonConverter<TStronglyTypedId, TValue> : JsonConverter<TStronglyTypedId>
      where TStronglyTypedId : IAbstractStronglyTypedId<TValue>
      where TValue : notnull {
    /// <summary>
    ///  This is the call to Deserialize an instance of an IAbstractStronglyTypedId
    /// </summary>
    /// <param name="reader"></param>
    /// <param name="typeToConvert"></param>
    /// <param name="options">The instance of the options contains a typeconverter for the specific type to convert</param>
    /// <returns> an object that implements an IAbstractRecordStronglyTypedId</returns>
    public override TStronglyTypedId Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) {
      if (reader.TokenType is JsonTokenType.Null) {
        return default;
      }

      var value = JsonSerializer.Deserialize<TValue>(ref reader, options);
      var factory = StronglyTypedIdHelper.GetFactory<TValue>(typeToConvert);
      return (TStronglyTypedId)factory(value);
    }


    [System.Diagnostics.CodeAnalysis.SuppressMessage("Usage", "CA1062:Seems like it could not happen", Justification = "No Internet examples show this test being done. performance.")]
    /// <summary>
    ///  This is the call to Serialize an instance of an IAbstractStronglyTypedId
    /// </summary>
    /// <param name="writer"></param>
    /// <param name="value"></param>
    /// <param name="options">The instance of the options contains a typeconverter for the specific type to convert</param>
    /// <returns> an object that implements an IAbstractRecordStronglyTypedId</returns>
    public override void Write(Utf8JsonWriter writer, TStronglyTypedId value, JsonSerializerOptions options) {///
      if (value is null) {
        writer.WriteNullValue();
      }
      else {
        JsonSerializer.Serialize(writer, value.Value, options);
      }
    }
  }

  /// <summary>
  /// A generic factory for any specific instance of the AbstractStronglyTypedId record type
  /// </summary>
  public class StronglyTypedIdJsonConverterFactory : JsonConverterFactory {

    /// <Summary>
    ///  A cache for converters, once created
    /// <Summary/>
    private static readonly ConcurrentDictionary<Type, System.Text.Json.Serialization.JsonConverter> Cache = new();
    /// <summary>
    ///  Returns true if the inquired upon type is one for whom a converter cna be created by this Factory
    /// </summary>
    /// <param name="typeToConvert"></param>
    /// <returns>true if the inquired upon type is one for whom a converter cna be created by this Factory</returns>
    public override bool CanConvert(Type typeToConvert) {
      return StronglyTypedIdHelper.IsStronglyTypedId(typeToConvert);
    }
    /// <summary>
    /// The method to get a converter of a specific type from the cache, or create one
    /// </summary>
    /// <param name="typeToConvert"></param>
    /// <param name="options"></param>
    /// <returns>An instance of the JsonCConverter for a specific instance of an ???</returns>
    public override System.Text.Json.Serialization.JsonConverter CreateConverter(Type typeToConvert, JsonSerializerOptions options) {
      return Cache.GetOrAdd(typeToConvert, CreateConverter);
    }
    /// <Summary>
    ///  the method to create a converter of a specific type
    /// <Summary/>
    private static System.Text.Json.Serialization.JsonConverter CreateConverter(Type typeToConvert) {
      if (!StronglyTypedIdHelper.IsStronglyTypedId(typeToConvert, out var valueType)) {
        throw new InvalidOperationException($"Cannot create converter for '{typeToConvert}'");
      }

      var type = typeof(StronglyTypedIdJsonConverter<,>).MakeGenericType(typeToConvert, valueType);
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
