using System;
using ATAP.Utilities.Serializer;
using System.Text.Json;
namespace ATAP.Utilities.TypedGuids.Serializer.SystemTextJson {
  public class TypedGuidConverterFactory<T> : SerializerConverterAbstract<Id<T>> {
    bool ISerializerConverterFactory<Id<T>>.CanConvert(Type typeToConvert) {
      throw new NotImplementedException();
    }

    ISerializerConverter<Id<T>> ISerializerConverterFactory<Id<T>>.CreateConverter(Type type, ISerializerOptions options) {
      throw new NotImplementedException();
    }
  }

  public class TypedGuidConverter<T> : ATAP.Utilities.Serializer.ISerializerConverter<Id<T>> {
    bool ISerializerConverter<Id<T>>.CanConvert(Type typeToConvert) {
      throw new NotImplementedException();
    }

    Id<T> ISerializerConverter<Id<T>>.Read(ref ISerializerReader reader, Type typeToConvert, ISerializerOptions options) {
      throw new NotImplementedException();
    }

    string ISerializerConverter<Id<T>>.ToString() {
      throw new NotImplementedException();
    }

    void ISerializerConverter<Id<T>>.Write(ISerializerWriter writer, Id<T> value, ISerializerOptions options) {
      throw new NotImplementedException();
    }
  }

  public class TypedGuidJsonConverter<T> : JsonConverter<T>
    where T : StronglyTypedId<TValue>
    where TValue : notnull
{
    public override T Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType is JsonTokenType.Null)
            return null;

        var value = JsonSerializer.Deserialize<Guid>(ref reader, options);
        var factory = StronglyTypedIdHelper.GetFactory<Guid>(typeToConvert);
        return (T)factory(value);
    }

    public override void Write(Utf8JsonWriter writer, T value, JsonSerializerOptions options)
    {
        if (value is null)
            writer.WriteNullValue();
        else
            JsonSerializer.Serialize(writer, value.Value, options);
    }
}
  /*
      public class ResultConverter<T> : JsonConverter {
      public override bool CanWrite => false;
      public override bool CanRead => true;
      public override bool CanConvert(Type objectType) {
          return objectType==typeof(Id<T>);
      }

      public override object ReadJson(JsonReader reader, Type objectType, object existingValue, JsonSerializer serializer) {
          var jsonObject = JObject.Load(reader);

if(System.Diagnostics.Debugger.IsAttached)
System.Diagnostics.Debugger.Break();
          Id<T> result = new Id<T> {
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
