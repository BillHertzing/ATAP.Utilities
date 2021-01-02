using System;

namespace ATAP.Utilities.Serializer {
  public interface ISerializer {
    string Serialize(object obj);
    string Serialize(object obj, ISerializerOptions options);
    T Deserialize<T>(string str);
    T Deserialize<T>(string str, ISerializerOptions options);
    void Configure();
    void Configure(ISerializerOptions options);
    void Configure(
      bool AllowTrailingCommas = false
      ,bool WriteIndented = false
      ,bool IgnoreNullValues = false
    );

  }

    public interface  ISerializerConverterFactory<T> {
      abstract bool CanConvert(Type typeToConvert);
      abstract ISerializerConverter<T> CreateConverter( Type type,
            ISerializerOptions options);
    }

    public interface  ISerializerConverter<T> {
      abstract bool CanConvert(Type typeToConvert);
      abstract string ToString();
      abstract T? Read (ref ISerializerReader reader, Type typeToConvert, ISerializerOptions options);
      abstract void Write (ISerializerWriter writer, T value, ISerializerOptions options);
    }

    public interface ISerializerReader  {

    }
    public interface ISerializerWriter : IDisposable { //IAsyncDisposable, 

    }


}
