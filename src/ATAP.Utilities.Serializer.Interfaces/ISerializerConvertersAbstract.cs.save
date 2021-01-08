using System;

namespace ATAP.Utilities.Serializer {

  public interface ISerializerConverterAbstractFactory {
    abstract bool CanConvert(Type typeToConvert);
    abstract ISerializerConverterAbstract CreateConverter(Type type); //, ISerializerOptions options);
  }

  public interface ISerializerConverterAbstract {
    abstract bool CanConvert(Type typeToConvert);
    abstract string ToString();
    abstract T? Read<T>(ref ISerializerReader reader, Type T, ISerializerOptions options);
    abstract void Write(ISerializerWriter writer, T value, ISerializerOptions options);
  }

  public interface ISerializerReader {

  }
  public interface ISerializerWriter : IDisposable { //IAsyncDisposable,

  }


}
