using System;
using System.Collections.Generic;
using System.Reflection;
using System.Linq;

using Microsoft.Extensions.DependencyInjection;

namespace ATAP.Utilities.Serializer {
  public static class SerializerLoader {
    // Search for all assemblies that have a class that implements ISerializer
    // return the first one
    public static ISerializer LoadSerializerFromAssembly() {
      // ToDo: get the one that matches configuration, otherwise get the first one
      // ToDo: Load that assembly
      // Get the type that implements ISerializer from the loaded assembly
      // return that type
      // ToDo: this block of code is temporary
      var _serializerShimName = "ATAP.Utilities.Serializer.Shim.SystemTextJson.dll";
      var _serializerShimNamespace = "ATAP.Utilities.Serializer";
      var types = Assembly.LoadFrom(_serializerShimName)
        .GetTypes()
        .Where(w => w.Namespace == _serializerShimNamespace && w.IsClass)
        .ToList();
      return types[0] as ISerializer;
      // ToDo: end of this block of code is temporary
    }

    // Search for all assemblies that have a class that implements ISerializer
    // add the first one to the IServices collection
    public static void LoadSerializerFromAssembly(IServiceCollection services) {
      // ToDo: get the one that matches configuration, otherwise get the first one
      // ToDo: Load that assembly
      var _serializerShimName = "ATAP.Utilities.Serializer.Shim.SystemTextJson.dll";
      var _serializerShimNamespace = "ATAP.Utilities.Serializer";
      var types = Assembly.LoadFrom(_serializerShimName)
        .GetTypes()
        .Where(w => w.Namespace == _serializerShimNamespace && w.IsClass)
        .ToList();
        services.AddSingleton(types[0].GetInterface("I" + types[0].Name, false), types[0]);
      // ToDo: end of this block of code is temporary
    }
    public static ISerializer LoadSerializerFromAssembly(string serializerShimName, string serializerShimNamespace) {
      //ToDo: validation of arguments
      // ToDo: Test to ensure the assembly specified in the Configuration exists in any of the places probed by assembly load
      var types = Assembly.LoadFrom(serializerShimName)
        .GetTypes()
        .Where(w => w.Namespace == serializerShimNamespace && w.IsClass)
        .ToList();
        //ToDo: verify the list of types always starts with a Serializer
        //ToDo: wrap in a try/catch block and handle exceptions, including probing additional paths
        ISerializer serializer = (ISerializer)Activator.CreateInstance(types[0]);
        return serializer;

      // Search for all assemblies that have a class implements ISerializer
      // ToDo: get the one that matches configuration, otherwise get the first one
      // ToDo: Load that assembly
      // Get the type that implements ISerializer from the loaded assembly
      // return that type

    }
    public static void LoadSerializerFromAssembly(string serializerShimName, string serializerShimNamespace, IServiceCollection services) {
      //ToDo: validation of arguments
      // ToDo: Test to ensure the assembly specified in the Configuration exists in any of the places probed by assembly load
      Assembly.LoadFrom(serializerShimName)
        .GetTypes()
        .Where(w => w.Namespace == serializerShimNamespace && w.IsClass)
        .ToList()
        .ForEach(t => {
          services.AddSingleton(t.GetInterface("I" + t.Name, false), t);
        });

      // Search for all assemblies that have a class implements ISerializer
      // ToDo: get the one that matches configuration, otherwise get the first one
      // ToDo: Load that assembly
      // Get the type that implements ISerializer from the loaded assembly
      // return that type
      return;
    }

  }
}
