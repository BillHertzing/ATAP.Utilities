using System;
using System.Runtime.Serialization;

namespace ATAP.Utilities.Serializer
{
    public static class SerializerLoader
  {
    public static ISerializer LoadSerializerFromAssembly() {
      // Search for all assemblies that have a class implements ISerializer
      // ToDo: get theone that matches configuration, otherwise get the first one
      // ToDo: Load that assembly
      // Get the type that implements ISerializer from the loaded assembly
      // return that type
      return new ATAP.Utilities.Serializer.Serializer();
    }

  }
}
