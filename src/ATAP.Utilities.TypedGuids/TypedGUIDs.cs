using System;

using ATAP.Utilities.Serializer;
namespace ATAP.Utilities.TypedGuids {
  //Attribution: taken from answers provided to this question: https://stackoverflow.com/questions/53748675/strongly-typed-guid-as-generic-struct
  // Modifications:  CheckValue and all references removed, because our use case requires Guid.Empty to be a valid value
  public struct Id<T> : IEquatable<Id<T>>, IId<T> {
    private readonly Guid _value;

    public Id(string value) {
      bool success;
      string iValue;
      if (string.IsNullOrEmpty(value)) {
        _value = Guid.NewGuid();
      }
      else {
        // Hack, used because only ServiceStack Json serializers add extra enclosing ".
        //  but, neither simpleJson nor NewtonSoft will serialize this at all
        iValue = value.Trim('"');
        success = Guid.TryParse(iValue, out Guid newValue);
        if (!success) { throw new NotSupportedException($"Guid.TryParse failed, value {value} cannot be parsed as a GUID"); }
        _value = newValue;
      }
    }

    public Id(Guid value) {
      _value = value;
    }

    public override bool Equals(object obj) {
      return obj is Id<T> id && Equals(id);
    }

    public bool Equals(Id<T> other) {
      return _value.Equals(other._value);
    }

    public override int GetHashCode() => _value.GetHashCode();

    public override string ToString() {
      return _value.ToString();
    }

    public static bool operator ==(Id<T> left, Id<T> right) {
      return left.Equals(right);
    }

    public static bool operator !=(Id<T> left, Id<T> right) {
      return !(left == right);
    }
  }
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
