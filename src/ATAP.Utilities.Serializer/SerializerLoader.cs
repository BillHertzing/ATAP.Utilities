using System;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.Loader;
using System.Linq;
using System.IO;

using Microsoft.Extensions.Configuration;

using McMaster.NETCore.Plugins;

using serializerStringConstants = ATAP.Utilities.Serializer.StringConstants;

using Microsoft.Extensions.DependencyInjection;

namespace ATAP.Utilities.Serializer {
  class SerializerLoadContext : AssemblyLoadContext {
    private AssemblyDependencyResolver _resolver;

    public SerializerLoadContext(string serializerPath) {
      _resolver = new AssemblyDependencyResolver(serializerPath);
    }

    protected override Assembly Load(AssemblyName assemblyName) {
      string assemblyPath = _resolver.ResolveAssemblyToPath(assemblyName);
      if (assemblyPath != null) {
        //ToDo: wrap in try/catch and handle exceptions
        return LoadFromAssemblyPath(assemblyPath);
      }
      return null;
    }
  }


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
    // public static void LoadSerializerFromAssembly(IServiceCollection services) {
    //   // ToDo: get the one that matches configuration, otherwise get the first one
    //   // ToDo: Load that assembly
    //   var _serializerShimName = "ATAP.Utilities.Serializer.Shim.SystemTextJson.dll";
    //   var _serializerShimNamespace = "ATAP.Utilities.Serializer";
    //   var types = Assembly.LoadFrom(_serializerShimName)
    //     .GetTypes()
    //     .Where(w => w.Namespace == _serializerShimNamespace && w.IsClass)
    //     .ToList();
    //     services.AddSingleton(types[0].GetInterface("I" + types[0].Name, false), types[0]);
    //   // ToDo: end of this block of code is temporary
    // }
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
      var fullpath = AppDomain.CurrentDomain.BaseDirectory + "Serializers\\" + serializerShimName + ".dll";
      Assembly.LoadFrom(fullpath)
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
    
    public static void LoadSerializerFromAssembly(string serializerShimName, string serializerShimNamespace, string[] relativePathsToProbe, IServiceCollection services) {
      // ToDo: validation of arguments
      // ToDo: Test to ensure the assembly specified in the Configuration exists in any of the places probed by assembly load
      var loaders = new List<PluginLoader>();

      // create serializer plugin loader for the serializerShimName
      foreach (var pathToProbe in relativePathsToProbe) {

        var pluginsDir = Path.Combine(AppContext.BaseDirectory, pathToProbe);
        // DLLs not in any subdirectory
        string pathToSerializerShimDll = Path.Combine(pluginsDir, serializerShimName + ".dll");
        if (File.Exists(pathToSerializerShimDll)) {
          var loader = PluginLoader.CreateFromAssemblyFile(
              pathToSerializerShimDll,
              sharedTypes: new[] { typeof(ISerializer) });
          loaders.Add(loader);
        }
        // DLLs found in any direct subdirectory
        foreach (string directory in Directory.GetDirectories(pluginsDir)) {
          pathToSerializerShimDll = Path.Combine(directory, serializerShimName + ".dll");
          if (File.Exists(pathToSerializerShimDll)) {
            var loader = PluginLoader.CreateFromAssemblyFile(
                pathToSerializerShimDll,
                sharedTypes: new[] { typeof(ISerializer) });
            loaders.Add(loader);
          }
        }
        // DLLs found in any child subdirectory tree
        // Create an instance of serializer types
        foreach (var loader in loaders) {
          foreach (var pluginType in loader
              .LoadDefaultAssembly()
              .GetTypes()
              .Where(t => typeof(ISerializer).IsAssignableFrom(t) && !t.IsAbstract && t.Namespace == serializerShimNamespace)) {
            // ToDo: validate that only one is returned
            // This assumes the implementation of IPlugin has a parameterless constructor
            ISerializer serializer = (ISerializer)Activator.CreateInstance(pluginType);
            services.AddSingleton(typeof(ISerializer), (ISerializer)Activator.CreateInstance(pluginType));
          }
        }
      }
      return;
    }
    public static void LoadSerializerFromAssembly(IConfiguration configuration, IServiceCollection services) {
      var _serializerShimName = configuration.GetValue<string>(serializerStringConstants.SerializerAssemblyConfigRootKey, serializerStringConstants.SerializerAssemblyDefault);
      var _serializerShimNamespace = configuration.GetValue<string>(serializerStringConstants.SerializerNamespaceConfigRootKey, serializerStringConstants.SerializerNamespaceDefault);

      // ToDo: validation of arguments
      // ToDo: Test to ensure the assembly specified in the Configuration exists in any of the places probed by assembly load
      Assembly.LoadFrom(_serializerShimName)
        .GetTypes()
        .Where(w => w.Namespace == _serializerShimNamespace && w.IsClass)
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
    // Assembly.LoadFrom(_serializerShimName)
    //   .GetTypes()
    //   .Where(w => w.Namespace == _serializerShimNamespace && w.IsClass)
    //   .ToList()
    //   .ForEach(t => {
    //     services.AddSingleton(t.GetInterface("I" + t.Name, false), t);
    //   });
    //   List<Assembly> assemblies = new List<Assembly>();
    //   foreach (string assemblyPath in Directory.GetFiles(System.AppDomain.CurrentDomain.BaseDirectory, "*.dll", SearchOption.AllDirectories)) {
    //     Assembly assembly = Assembly.LoadFile(assemblyPath);
    //     assemblies.Add(assembly);
    //   }
    //   services.Scan(scan => scan // Scan comes fro Scrutor package
    //     .FromAssemblies(assemblies)
    //     .AddClasses(classes => classes.AssignableTo<ISerializer>(), publicOnly: false)
    //     .AsImplementedInterfaces()
    //     .WithTransientLifetime());

  }
}
