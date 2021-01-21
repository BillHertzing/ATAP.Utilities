using System;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.Loader;
using System.Linq;
using System.IO;

using Microsoft.Extensions.Configuration;
using static ATAP.Utilities.FileIO.Extensions;
using static ATAP.Utilities.Collection.Extensions;

using ATAP.Utilities.FileIO;

// ToDo figure out how to make the Loader a runtime plugun
// Currently this code only works with the McMaster Loader, it is hardcoded
using McMaster.NETCore.Plugins;

using LoaderStringConstants = ATAP.Utilities.Loader.StringConstants;

//using DotNet.Globbing;

using Microsoft.Extensions.DependencyInjection;

namespace ATAP.Utilities.Loader {
  /// <summary>
  /// The  <see cref="DynamicGlobAndPredicate"> record identifies assemblies to load and from that assembly a predicate to match specific types
  /// </summary>
  public record DynamicGlobAndPredicate : IDynamicGlobAndPredicate {
    public Glob Glob { get; init; }
    public Predicate<Type> Predicate { get; init; }
  }

  /// <summary>
  /// detailed information for loading submodules for a specific dynamic Type,
  /// </summary>
  public record DynamicSubModulesInfo : IDynamicSubModulesInfo {
    /// <summary>
    /// The  <see cref="DynamicGlobAndPredicate"> property contains a globbing pattern to find libraries and then types to load
    /// </summary>
    public IDynamicGlobAndPredicate DynamicGlobAndPredicate { get; init; }
    /// <summary>
    /// The <see cref="Function"> property contains an Action delegate called for each dynamic type that gets instantiated
    /// </summary>
    public Action<object> Function { get; init; }
  }

  public abstract class LoaderAbstract<IType> {
    public abstract void LoadExactlyOneInstanceOfITypeFromAssemblyGlobAsSingleton(IDynamicGlobAndPredicate dynamicGlobAndPredicate, IServiceCollection services);
    public abstract IType LoadExactlyOneInstanceOfITypeFromAssemblyGlob(IDynamicGlobAndPredicate dynamicGlobAndPredicate = default);
    public abstract void LoadAndProcessZeroOrMoreInstanceOfITypeFromAssemblyGlob(IDynamicGlobAndPredicate dynamicGlobAndPredicate, Action<Type, object> action);
  }

  public class LoaderFactory {
    // public LoaderAbstract<Type> GetLoader(Type TypeToLoad) {
    //   Type genericLoaderType = typeof(Loader<>);
    //   Type constructedLoaderType = genericLoaderType.MakeGenericType(TypeToLoad);
    //   return new Loader<constructedLoaderType>();
    // }
  }

  // todo: constructor injection of Logger and exception_Localizer
  public class Loader<IType> : LoaderAbstract<IType> {
    public override void LoadExactlyOneInstanceOfITypeFromAssemblyGlobAsSingleton(IDynamicGlobAndPredicate dynamicGlobAndPredicate, IServiceCollection services) {
      // ToDo: Localize this exception
      if (dynamicGlobAndPredicate == default) { throw new ArgumentNullException(nameof(dynamicGlobAndPredicate)); }
      IType instance;
      // allow any exception thrown in lower level to bubble up through here
      instance = LoadExactlyOneInstanceOfITypeFromAssemblyGlob(dynamicGlobAndPredicate);
      if (instance == null) { throw new NullReferenceException("ToDo: instance cannot be null. Glob: {0}, Predicate: {3}"); }
      // ToDo: Support Transient and Scoped
      services.AddSingleton(typeof(IType), instance);
      return;
    }
    public override IType LoadExactlyOneInstanceOfITypeFromAssemblyGlob(IDynamicGlobAndPredicate dynamicGlobAndPredicate = default) {
      var loaders = new List<PluginLoader>();
      var allShimNames = dynamicGlobAndPredicate.Glob.ExpandNames();
      IType singleInstance;
      // ToDo: fix an issue if the Glob pattern (file suffix) differs in case from the actual file name, it throws an exception
      foreach (string shimName in allShimNames) {
        var loader = PluginLoader.CreateFromAssemblyFile(
        shimName,
        sharedTypes: new[] { typeof(IType) });
        loaders.Add(loader);
      }
      var loaderHavingTypeMatchingPredicateCollection = new List<PluginLoader>();
      foreach (var loader in loaders) {
        var typesFromDynamicallyLoadedAssemblyMatchingPredicate = loader
             .LoadDefaultAssembly()
             .GetTypes()
             .Where(_type => dynamicGlobAndPredicate.Predicate(_type));
        if (typesFromDynamicallyLoadedAssemblyMatchingPredicate.Any()) {
          loaderHavingTypeMatchingPredicateCollection.Add(loader);
        }
      }
      // Validate the sequence of loaders has exactly one element
      if (!loaderHavingTypeMatchingPredicateCollection.HasSingle<PluginLoader>(out PluginLoader singleLoader)) {
        //ToDo: add custom exception to Loader assembly
        throw new System.Exception("ToDo: localize this message loaderHavingTypeMatchingPredicateCollection must have exactly one");
      }
      var typeMatchesPredicateCollection = singleLoader
          .LoadDefaultAssembly()
          .GetTypes()
          .Where(_type => dynamicGlobAndPredicate.Predicate(_type));
      if (!typeMatchesPredicateCollection.HasSingle<Type>(out Type singleType)) {
        throw new System.Exception("ToDo: localize this message typeMatchesPredicateCollection must have exactly one");
      }
      // This assumes the implementation of IType has a parameterless constructor
      singleInstance = (IType)Activator.CreateInstance(singleType);
      // Does the instance (or pluginLoader) indicate that instance implements the ILoadDynamicSubModules interface
      bool hasDynamicSubModules = singleLoader.LoadDefaultAssembly().GetTypes().Where(_type => typeof(ILoadDynamicSubModules).IsAssignableFrom(_type) && dynamicGlobAndPredicate.Predicate(_type)).Any();
      if (hasDynamicSubModules) {
        // find and load any additional dynamic modules to load as specified by the actual instance
        // Get the dictionary (by Type) of (functions (by enumeration expected cardinalityofresults (0,1,many) to be applied to each Cardinailty:(collection or individual) submodule Types, using relativePathsToProbe, pattern for finding the submodule .dll files in the existing relativePathsToProbe, , subModuleNamespace
        var subTypesToFunctionGlobCriteriaDictionary = ((ILoadDynamicSubModules)singleInstance).GetDynamicSubModulesInfo();
        // Iterate
        foreach (var subModuleIType in subTypesToFunctionGlobCriteriaDictionary.Keys) {
          var subModulesInfo = subTypesToFunctionGlobCriteriaDictionary[subModuleIType];
          // var genericLoaderType = typeof(Loader<subModuleIType.GetType() >).MakeGenericType(subModuleIType.GetType());
          // var genericLoaderInstance = Activator.CreateInstance(typeof(genericLoaderType));
          // var iType = subModuleIType.GetType();
          // var genericLoader = typeof(Loader<>).MakeGenericType(subModuleIType.GetType());
          // var subModuleLoader = (Loader<type>)Activator.CreateInstance(type);
          // subModuleLoader.LoadAndProcessZeroOrMoreInstanceOfITypeFromAssemblyGlob(subModulesInfo.DynamicGlobAndPredicate, subModulesInfo.Function);
          // subModuleLoader.LoadManyInstanceOfITypeFromAssemblyGlob(subModuleIType, subModuleDynamicGlobAndPredicate);
          // ToDo: add upperbound test for number of iterations/depth that submodules can be loaded, raise custom exception if it happens
        }
      }

      return singleInstance;
    }
    public override void LoadAndProcessZeroOrMoreInstanceOfITypeFromAssemblyGlob(IDynamicGlobAndPredicate dynamicGlobAndPredicate, Action<Type, object> action) {
      // ToDo: add parameter checking
      var loaders = new List<PluginLoader>();
      var allShimNames = dynamicGlobAndPredicate.Glob.ExpandNames();
      //IEnumerable ZeroOrMoreInstanceCollection;
      // ToDo: fix an issue if the Glob pattern (file suffix) differs in case from the actual file name, it throws an exception
      foreach (string shimName in allShimNames) {
        var loader = PluginLoader.CreateFromAssemblyFile(
        shimName,
        sharedTypes: new[] { typeof(IType) });
        loaders.Add(loader);
      }
      var loaderHavingTypeMatchingPredicateCollection = new List<PluginLoader>();
      foreach (var loader in loaders) {
        var typesFromDynamicallyLoadedAssemblyMatchingPredicate = loader
             .LoadDefaultAssembly()
             .GetTypes()
             .Where(_type => dynamicGlobAndPredicate.Predicate(_type));
        if (typesFromDynamicallyLoadedAssemblyMatchingPredicate.Any()) {
          loaderHavingTypeMatchingPredicateCollection.Add(loader);
        }
      }
      foreach (PluginLoader loader in loaderHavingTypeMatchingPredicateCollection) {
        var typeMatchesPredicateCollection = loader
            .LoadDefaultAssembly()
            .GetTypes()
            .Where(_type => dynamicGlobAndPredicate.Predicate(_type));
        // a single assembly may contain many types that match the predicate
        foreach (Type matchingType in typeMatchesPredicateCollection) {
          // This assumes the implementation of IType has a parameterless constructor
          // ToDo: wrap in a try/catch and handle exceptions
          var singleInstance = (IType)Activator.CreateInstance(matchingType);
          // pass the singleInstance of the matchingType to the Action
          action(matchingType, singleInstance!);
        }
      }
    }
  }

  // public record DynamicShimNameAndNamespaceConfigRootKeyAndDefaultValue(string DynamicShimNameConfigRootKey, string DynamicShimNameConfigDefault, string DynamicShimNamespaceConfigRootKey, string DynamicShimNamespaceConfigurationDefault) : IDynamicShimNameAndNamespaceConfigRootKeyAndDefaultValue;
  // public record DynamicShimNameAndNamespace(string DynamicShimName, string DynamicShimNamespace) : IDynamicShimNameAndNamespace;
  // public record DynamicShimNameAndNamespaceWithSubModules(string DynamicShimName, string DynamicShimNamespace) : IDynamicShimNameAndNamespace;
  // // toDo: figure out how to supply the functions needed for IEquality and others needed to make DynamicTypeToShimDictionary a record instead of a class
  // public class DynamicTypeToShimDictionary : IDynamicTypeToShimDictionary {
  //   public IDictionary<Type, IEnumerable<IDynamicShimNameAndNamespace>> DynamicTypeToShimCollection { get; init; }
  // }


  /// Finds assemblies that meet a criteria, imports them, gets Types that meet a criteria, either return them or add them to a IServices collection
  // public static class LoaderStatic<IType> {
  //   // Search for all assemblies that have a class that implements the IType interface
  //   // return the first one
  //   public static void LoadFromAssembly(IEnumerable<DynamicShimNameAndNamespaceConfigRootKeyAndDefaultValue> configurationShimPairKeyCollection, IConfiguration configuration, string[] relativePathsToProbe, IServiceCollection services) {
  //     //ToDo: wrap in a try/catch, and throw a LoaderException on failure
  //     IEnumerable<IType> instances = LoadFromAssembly(configurationShimPairKeyCollection, configuration, relativePathsToProbe);
  //     foreach (IType instance in instances) {
  //       // ToDo: Support Transient and Scoped
  //       services.AddSingleton(typeof(IType), instance!);
  //     }
  //     return;
  //   }
  //   public static IEnumerable<IType> LoadFromAssembly(IEnumerable<DynamicShimNameAndNamespaceConfigRootKeyAndDefaultValue> configurationShimPairKeyCollection, IConfiguration configuration, string[] relativePathsToProbe) {
  //     //ToDo: wrap in a try/catch, and throw a LoaderException on failure
  //     IEnumerable<IType> instances = LoadFromAssembly(configurationShimPairKeyCollection, configuration, relativePathsToProbe);
  //     return instances;
  //   }
  //   public static void LoadFromAssembly(IEnumerable<DynamicShimNameAndNamespace> shimPairCollection, string[] relativePathsToProbe, IServiceCollection services) {
  //     //ToDo: wrap in a try/catch, and throw a LoaderException on failure
  //     IEnumerable<IType> instances = LoadFromAssembly(shimPairCollection, relativePathsToProbe);
  //     // ToDo: test for at least one element in the collection, and throw a LoaderException on failure
  //     foreach (IType instance in instances) {
  //       // ToDo: Support Transient and Scoped
  //       services.AddSingleton(typeof(IType), instance!);
  //     }
  //     return;
  //   }
  //   public static IEnumerable<IType> LoadFromAssembly(IEnumerable<DynamicShimNameAndNamespace> shimPairCollection, string[] relativePathsToProbe) {
  //     //ToDo: wrap in a try/catch, and throw a LoaderException on failure
  //     IEnumerable<IType> instances = LoadFromAssembly(shimPairCollection, relativePathsToProbe);
  //     return instances;
  //   }
  //   public static void LoadFromAssembly(IEnumerable<DynamicShimNameAndNamespace>? shimPairCollection, IEnumerable<DynamicShimNameAndNamespaceConfigRootKeyAndDefaultValue>? configurationShimPairKeyCollection, string[] relativePathsToProbe, IConfiguration configuration, IServiceCollection services) {
  //     //ToDo: wrap in a try/catch, and throw a LoaderException on failure
  //     IEnumerable<IType> instances = LoadFromAssembly(shimPairCollection, configurationShimPairKeyCollection, relativePathsToProbe, configuration);
  //     // ToDo: test for at least one element in the collection, and throw a LoaderException on failure
  //     foreach (IType instance in instances) {
  //       // ToDo: Support Transient and Scoped
  //       services.AddSingleton(typeof(IType), instance!);
  //     }
  //   }
  // public static IEnumerable<IType> LoadFromAssembly(IEnumerable<DynamicShimNameAndNamespace>? shimPairCollection, IEnumerable<DynamicShimNameAndNamespaceConfigRootKeyAndDefaultValue>? configurationShimPairKeyCollection, string[] relativePathsToProbe, IConfiguration configuration) {
  //   if ((shimPairCollection == null) && (configurationShimPairKeyCollection == null || configuration == null)) {
  //     // ToDo: figure out how to get a stringlocalizer service visible here, so a localized exception message about the null arguments can be generated
  //     throw new ArgumentNullException("TBD: localized message that both selector mechanisms cannot be null");
  //   }
  //   if ((shimPairCollection != null) && (configurationShimPairKeyCollection != null && configuration != null)) {
  //     // ToDo: figure out how to get a stringlocalizer service visible here, so a localized exception message about the null arguments can be generated
  //     throw new ArgumentNullException("TBD: localized message that both selector mechanisms cannot be not-null");
  //   }
  //   List<IType> instances = new List<IType>();
  //   if (shimPairCollection != null) {
  //     foreach (DynamicShimNameAndNamespace shimPair in shimPairCollection) {
  //       instances.Add(LoadFromAssembly(shimPair.LoaderShimName, shimPair.LoaderShimNamespace, relativePathsToProbe));
  //     }
  //   }
  //   else {
  //     List<DynamicShimNameAndNamespace> _shimPairCollection = new List<DynamicShimNameAndNamespace>();
  //     // ToDo: Can this foreach loop be replaced with AddRange and a bit of Linq?
  //     foreach (DynamicShimNameAndNamespaceConfigRootKeyAndDefaultValue ConfigRootKeyAndDefaultValue in configurationShimPairKeyCollection) {
  //       var DynamicShimNameAndNamespace = new DynamicShimNameAndNamespace(
  //           configuration.GetValue<string>(ConfigRootKeyAndDefaultValue.DynamicShimNameConfigRootKey,
  //            ConfigRootKeyAndDefaultValue.DynamicShimNameConfigDefault),
  //           configuration.GetValue<string>(ConfigRootKeyAndDefaultValue.DynamicShimNameConfigRootKey,
  //            ConfigRootKeyAndDefaultValue.DynamicShimNameConfigDefault));
  //       _shimPairCollection.Add(DynamicShimNameAndNamespace);
  //     }
  //     foreach (DynamicShimNameAndNamespace shimPair in _shimPairCollection) {
  //       instances.Add(LoadFromAssembly(shimPair.LoaderShimName, shimPair.LoaderShimNamespace, relativePathsToProbe));
  //     }
  //   }
  //   return instances;
  // }
  /// The main code that calls the actual loader, McMaster in this case
  // ToDo: still need to think on how to dynamically decide which loader module to use..
  // public static void LoadFromAssembly(string loaderShimName, string loaderShimNamespace, string[] relativePathsToProbe, IServiceCollection services) {
  //   IType instance = LoadFromAssembly(loaderShimName, loaderShimNamespace, relativePathsToProbe);
  //   // ToDo: Support Transient and Scoped
  //   services.AddSingleton(typeof(IType), instance);
  // }
  //     public static IType LoadFromAssembly(string loaderShimName, string LoaderShimNamespace, string[] relativePathsToProbe) {
  // return LoadFromAssembly(loaderShimName, )
  //     }
  // public static IEnumerable<(Type, IEnumerable<Object>)> LoadFromAssembly(IDictionary<Type, DynamicShimCollection> DynamicShimCollectionForType, string[] relativePathsToProbe = default) {
  // }
  // // public static (Type, IEnumerable<Object>) LoadFromAssembly(Type type, IEnumerable<DynamicShimNameAndNamespace> DynamicShimNameAndNamespaceCollectionForType, string[] relativePathsToProbe = default) {
  // // }
  // public static IType LoadFromAssembly(string loaderShimName, string LoaderShimNamespace, string subModuleShimName = default, string subModuleShimNamespace = default, string[] relativePathsToProbe = default) {

  //   // ToDo: validation of arguments
  //   var loaders = new List<PluginLoader>();
  //   List<IType> instances = new();
  //   // create Loader plugin loader for the loaderShimName
  //   foreach (var pathToProbe in relativePathsToProbe) {
  //     var pluginsDir = Path.Combine(AppContext.BaseDirectory, pathToProbe);
  //     // DLLs not in any subdirectory
  //     string pathToLoaderShimDll = Path.Combine(pluginsDir, loaderShimName + ".dll");
  //     if (File.Exists(pathToLoaderShimDll)) {
  //       var loader = PluginLoader.CreateFromAssemblyFile(
  //           pathToLoaderShimDll,
  //           sharedTypes: new[] { typeof(IType) });
  //       loaders.Add(loader);
  //     }
  //     // DLLs found in any direct subdirectory
  //     foreach (string directory in Directory.GetDirectories(pluginsDir)) {
  //       pathToLoaderShimDll = Path.Combine(directory, loaderShimName + ".dll");
  //       if (File.Exists(pathToLoaderShimDll)) {
  //         var loader = PluginLoader.CreateFromAssemblyFile(
  //             pathToLoaderShimDll,
  //             sharedTypes: new[] { typeof(IType) });
  //         loaders.Add(loader);
  //       }
  //     }
  //     // ToDo: DLLs found in any child subdirectory tree
  //     // ToDo: Test to ensure the assembly specified in the Configuration exists in any of the places probed by assembly load
  //     // Create an instance of IType
  //     foreach (var loader in loaders) {
  //       foreach (var pluginType in loader
  //           .LoadDefaultAssembly()
  //           .GetTypes()
  //           .Where(t => typeof(IType).IsAssignableFrom(t) && !t.IsAbstract && t.Namespace == LoaderShimNamespace))
  //           // ToDo: Add test and exception if more than one is found
  //           {
  //         // This assumes the implementation of IType has a parameterless constructor
  //         var initialInstance = (IType)Activator.CreateInstance(pluginType);
  //         // Does the instance (or pluginLoader) indicate that instance implements the ILoadDynamicSubModules interface
  //         bool hasDynamicSubModules = loader.LoadDefaultAssembly().GetTypes().Where(t => typeof(ILoadDynamicSubModules).IsAssignableFrom(t) && typeof(IType).IsAssignableFrom(t) && !t.IsAbstract && t.Namespace == LoaderShimNamespace).Any();
  //         if (hasDynamicSubModules) {
  //           // find and load any additional dynamic modules to load as specified by the actual instance
  //           // // Get the dictionary (by Type) of (functions (by enumeration expected CardinalityOfResults (0,1,many) to be applied to each Cardinailty:(collection or individual) submodule Types, using relativePathsToProbe, pattern for finding the submodule .dll files in the existing relativePathsToProbe, , subModuleNamespace
  //           // var subTypesToFunctionCriteriaDictionary = ((ILoadDynamicSubModules)initialInstance).GetDynamicSubModulesInfo();
  //           // // Iterate
  //           // foreach (var kvp in subTypesToFunctionCriteriaDictionary) {
  //           //   ATAP.Utilities.Loader.Loader <.>.LoadFromAssembly(_serializerShimName, _serializerShimNamespace, new string[] { pluginsDirectory }
  //           //   }

  //           // This may iterate multiple submodules to load
  //           // ToDo: add upperbound test for number of iterations/depth that submodules can be loaded, raise custom exception if it happens
  //         }
  //         // find any Loader subModuleType converters in any loaded assembly
  //         instances.Add(initialInstance);
  //         //ToDo: make this generic not specific
  //         // instance.LoadDynamicSubModules(loaderShimName, LoaderShimNamespace);
  //       }
  //     }
  //   }
  //   // ToDo: validate that only one is returned
  //   var instance = instances.First<IType>();
  //   if (subModuleShimName != default && subModuleShimNamespace != default) {
  //     //  ToDo: need to enforce that the interface and instance supply LoadSubModules(IEnumerable<ModuleNameAndNamespacePair>)
  //     instance.LoadSubModules(subModuleShimName, subModuleShimNamespace, relativePathsToProbe);
  //   }
  //   return instance;
  // }

  // public abstract static IDictionary<Type, IDynamicSubModulesInfo<Type>> GetDynamicSubModulesInfo() {

  // }
  // public static void LoadSubModules(IType instance, string loaderShimName, string LoaderShimNamespace, string[] relativePathsToProbe) {

  //  }

  // class LoaderLoadContext : AssemblyLoadContext {
  //   private AssemblyDependencyResolver _resolver;

  //   public LoaderLoadContext(string LoaderPath) {
  //     _resolver = new AssemblyDependencyResolver(LoaderPath);
  //   }

  //   protected override Assembly Load(AssemblyName assemblyName) {
  //     string assemblyPath = _resolver.ResolveAssemblyToPath(assemblyName);
  //     if (assemblyPath != null) {
  //       //ToDo: wrap in try/catch and handle exceptions
  //       return LoadFromAssemblyPath(assemblyPath);
  //     }
  //     return null;
  //   }
  // }

  // Assembly.LoadFrom(_LoaderShimName)
  //   .GetTypes()
  //   .Where(w => w.Namespace == _LoaderShimNamespace && w.IsClass)
  //   .ToList()
  //   .ForEach(t => {
  //     services.AddSingleton(t.GetInterface("I" + t.Name, false), t);
  //   });
  //   List<Assembly> assemblies = new List<Assembly>();
  //   foreach (string assemblyPath in Directory.GetFiles(System.AppDomain.CurrentDomain.BaseDirectory, "*.dll", SearchOption.AllDirectories)) {
  //     Assembly assembly = Assembly.LoadFile(assemblyPath);
  //     assemblies.Add(assembly);
  //   }
  //   services.Scan(scan => scan // Scan comes from the Scrutor package
  //     .FromAssemblies(assemblies)
  //     .AddClasses(classes => classes.AssignableTo<ILoader>(), publicOnly: false)
  //     .AsImplementedInterfaces()
  //     .WithTransientLifetime());

  // public static void LoadFromAssembly(string loaderShimName, string LoaderShimNamespace, IServiceCollection services) {
  //       //ToDo: validation of arguments
  //       // ToDo: Test to ensure the assembly specified in the Configuration exists in any of the places probed by assembly load
  //       var fullpath = AppDomain.CurrentDomain.BaseDirectory + "Plugins\\" + loaderShimName + ".dll";
  //       Assembly.LoadFrom(fullpath)
  //         .GetTypes()
  //         .Where(w => w.Namespace == LoaderShimNamespace && w.IsClass)
  //         .ToList()
  //         .ForEach(t => {
  //           services.AddSingleton(t.GetInterface("I" + t.Name, false), t);
  //         });

  //       // Search for all assemblies that have a class implements ILoader
  //       // ToDo: get the one that matches configuration, otherwise get the first one
  //       // ToDo: Load that assembly
  //       // Get the subModuleType that implements ILoader from the loaded assembly
  //       // return that subModuleType
  //       return;
  //     }
  //     public static void LoadFromAssembly(IConfiguration configuration, IServiceCollection services) {
  //       var _LoaderShimName = configuration.GetValue<string>(LoaderStringConstants.LoaderAssemblyConfigRootKey, LoaderStringConstants.LoaderAssemblyDefault);
  //       var _LoaderShimNamespace = configuration.GetValue<string>(LoaderStringConstants.LoaderNamespaceConfigRootKey, LoaderStringConstants.LoaderNamespaceDefault);

  //       // ToDo: validation of arguments
  //       // ToDo: Test to ensure the assembly specified in the Configuration exists in any of the places probed by assembly load
  //       Assembly.LoadFrom(_LoaderShimName)
  //         .GetTypes()
  //         .Where(w => w.Namespace == _LoaderShimNamespace && w.IsClass)
  //         .ToList()
  //         .ForEach(t => {
  //           services.AddSingleton(t.GetInterface("I" + t.Name, false), t);
  //         });

  //       // Search for all assemblies that have a class implements ILoader
  //       // ToDo: get the one that matches configuration, otherwise get the first one
  //       // ToDo: Load that assembly
  //       // Get the subModuleType that implements ILoader from the loaded assembly
  //       // return that subModuleType
  //       return;
  //     }

  //     public static void LoadFromAssembly(IConfiguration configuration, IServiceCollection services) {
  //       var _LoaderShimName = configuration.GetValue<string>(LoaderStringConstants.LoaderAssemblyConfigRootKey, LoaderStringConstants.LoaderAssemblyDefault);
  //       var _LoaderShimNamespace = configuration.GetValue<string>(LoaderStringConstants.LoaderNamespaceConfigRootKey, LoaderStringConstants.LoaderNamespaceDefault);

  //       // ToDo: validation of arguments
  //       // ToDo: Test to ensure the assembly specified in the Configuration exists in any of the places probed by assembly load
  //       Assembly.LoadFrom(_LoaderShimName)
  //         .GetTypes()
  //         .Where(w => w.Namespace == _LoaderShimNamespace && w.IsClass)
  //         .ToList()
  //         .ForEach(t => {
  //           services.AddSingleton(t.GetInterface("I" + t.Name, false), t);
  //         });

  //       // Search for all assemblies that have a class implements ILoader
  //       // ToDo: get the one that matches configuration, otherwise get the first one
  //       // ToDo: Load that assembly
  //       // Get the subModuleType that implements ILoader from the loaded assembly
  //       // return that subModuleType
  //       return;
  //     }

  // }
}
