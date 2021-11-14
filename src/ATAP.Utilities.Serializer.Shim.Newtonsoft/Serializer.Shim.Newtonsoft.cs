using System;
using System.Collections.Generic;
using Newtonsoft.Json;

using ATAP.Utilities.Serializer;

using static ATAP.Utilities.Collection.Extensions;

namespace ATAP.Utilities.Serializer.Shim.Newtonsoft {
  public class Serializer : ISerializer {
    public ISerializerOptions Options { get;  set; }
    // private JsonSerializerSettings NewtonsoftSerializerSettings { get; set; }
    public Serializer() {
      this.Configure();
    }

    public Serializer(ISerializerOptions options) {
      this.Configure(options);
    }
    public Serializer(JsonSerializerSettings options) {
      this.Configure(options);
    }
    // public Serializer(List<JsonConverter> jsonConverters) {
      // this.Configure(jsonConverters);
    // }

    public string Serialize(object obj) {
      return JsonConvert.SerializeObject(obj, (JsonSerializerSettings)Options.ShimSpecificOptions);
    }
    public T Deserialize<T>(string str) {
      return JsonConvert.DeserializeObject<T>(str, (JsonSerializerSettings)Options.ShimSpecificOptions);
    }
    public string Serialize(object obj, ISerializerOptions options) {
      return JsonConvert.SerializeObject(obj, (JsonSerializerSettings)options.ShimSpecificOptions);
    }
    public T Deserialize<T>(string str, ISerializerOptions options) {
      return JsonConvert.DeserializeObject<T>(str, (JsonSerializerSettings)options.ShimSpecificOptions);
    }

    // ToDo: add a Configure which has default values of the Options should come from an IConfiguration object, and keys/default values should come from a StringConstants
    public void Configure() {
      //
      Options = new SerializerOptions(new JsonSerializerSettings());
      // ToDo: Add a method that returns a specific list of JsonConverter which would be the default for ATAP utilities
      //JsonConvertersCache = new List<JsonConverter>() {
      // DictionaryJsonConverterFactory.Default
      // };
    }
    public void Configure(ISerializerOptions options) {
      Options = new SerializerOptions(options);
      //JsonConvertersCache = new List<JsonConverter>();
      //JsonConvertersCache.AddRange(((JsonSerializerOptions)Options).ShimSpecificOptions.Converters)
      //((JsonSerializerOptions)Options).ShimSpecificOptions.PopulateConverters(JsonConvertersCache);
    }
    public void Configure(JsonSerializerSettings serializerOptions) {
      Options = new SerializerOptions(serializerOptions);
    }
    // public void Configure(List<JsonConverter> jsonConverters) {
      // Options = new SerializerOptions(new JsonSerializerOptions());
      // // ToDo: Null Check
      // //JsonConvertersCache = jsonConverters;
      // //((JsonSerializerOptions)Options.ShimSpecificOptions).PopulateConverters(jsonConverters);
      // foreach (var converter in jsonConverters) {
        // ((JsonSerializerOptions)Options.ShimSpecificOptions).Converters.Add(converter);
      // }
    // }

    // This module, if loaded dynamically, has submodules which must be loaded dynamically as well
    // ToDo: make a separate assembly, to be included only if the code will be loaded dynamically
    /// <summary>
    /// returns a dictionary, keyed by type, with a DynamicSubModulesInfo for each type
    /// </summary>
    ///// <returns>IDictionary<Type, ISubModulesInfo></returns>
      //public IDictionary<Type, IDynamicSubModulesInfo> GetDynamicSubModulesInfo() {
      //      Dictionary<Type, IDynamicSubModulesInfo> dynamicSubModulesInfoDictionary = new();
      // dynamicSubModulesInfoDictionary[typeof(JsonConverter)] = new DynamicSubModulesInfo() {
        // DynamicGlobAndPredicate = new DynamicGlobAndPredicate() {
          // Glob = new Glob() {
            // Pattern = ".\\Plugins\\*JsonConverter.Shim.Newtonsoft.dll"
          // },
          // Predicate = new Predicate<Type>(
          // _type => {
            // return
              // typeof(JsonConverter).IsAssignableFrom(_type)
              // && !_type.IsAbstract
              // && _type.Namespace == "ATAP.Utilities.Serializer.Shim.Newtonsoft"
            // ;
          // }
         // )
        // },
        // Function = new Action<object>((instance) => { JsonConvertersCache.Add((JsonConverter)instance); return; })
      // };
      //return dynamicSubModulesInfoDictionary;
    //     return new Dictionary<Type, IDynamicSubModulesInfo>();
    //  }

    // public void LoadJsonConverters(string jsonConverterShimName, string jsonConverterShimNamespace, string[] relativePathsToProbe) {
      // // Load all Plugin Assemblies with a name that matches the serializerShimName
      // // get all types that implement JsonConverter
      // // cache them and also add them to the JsonSerializerOptions
      // //JsonConverterFactorysCache.Add();
    // }
    // public void LoadJsonConverterFactorys(string jsonConverterFactoryShimName, string jsonConverterFactoryShimNamespace, string[] relativePathsToProbe) {
      // // Load all Plugin Assemblies with a name that matches the serializerShimName
      // // get all types that implement JsonConverterFactory (aka the open generic JsonConverter<T>)
      // // cache them and also add them to the JsonSerializerOptions
      // //JsonConverterFactorysCache.Add();
    // }
  }
}
