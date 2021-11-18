using System;
using System.Collections.Generic;
using Newtonsoft.Json;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Serializer;

using static ATAP.Utilities.Collection.Extensions;

namespace ATAP.Utilities.Serializer.Shim.Newtonsoft {

  public class Serializer : SerializerConfigurableAbstract {
    public Serializer() {
      this.Configure();
    }
    public Serializer(IConfigurationRoot? configurationRoot) {
      this.Configure(configurationRoot);
    }

    public Serializer(ISerializerOptionsAbstract options) {
      this.Configure(options);
    }
    public Serializer(ISerializerOptionsAbstract options, IConfigurationRoot? configurationRoot) {
      this.Configure(options, configurationRoot);
    }
    // public Serializer(JsonSerializerSettings options) {
    //   this.Configure(options);
    // }
    // public Serializer(List<JsonConverter> jsonConverters) {
    // this.Configure(jsonConverters);
    // }

    public override string Serialize(object obj) {
      return JsonConvert.SerializeObject(obj, (JsonSerializerSettings)Options.ShimSpecificOptions);
    }
    public override T Deserialize<T>(string str) {
      return JsonConvert.DeserializeObject<T>(str, (JsonSerializerSettings)Options.ShimSpecificOptions);
    }
    public override string Serialize(object obj, ISerializerOptionsAbstract options) {
      return JsonConvert.SerializeObject(obj, (JsonSerializerSettings)options.ShimSpecificOptions);
    }
    public override T Deserialize<T>(string str, ISerializerOptionsAbstract options) {
      return JsonConvert.DeserializeObject<T>(str, (JsonSerializerSettings)options.ShimSpecificOptions);
    }

    public override void Configure() {
      this.Configure(new SerializerOptions(new JsonSerializerSettings()), null);

      // ToDo: Add a method that returns a specific list of JsonConverter which would be the default for ATAP utilities
      //JsonConvertersCache = new List<JsonConverter>() {
      // DictionaryJsonConverterFactory.Default
      // };
    }
    public override void Configure(IConfigurationRoot? configurationRoot) {
      // Store the configurationRoot in the serializer
      // Configure the serializer according to any settings in the configurationRoot
      base.Configure(configurationRoot);
    }
    public override void Configure(ISerializerOptionsAbstract options) {
      base.Configure(options);
      //JsonConvertersCache = new List<JsonConverter>();
      //JsonConvertersCache.AddRange(((JsonSerializerOptions)Options).ShimSpecificOptions.Converters)
      //((JsonSerializerOptions)Options).ShimSpecificOptions.PopulateConverters(JsonConvertersCache);
    }
    public override void Configure(ISerializerOptionsAbstract options, IConfigurationRoot? configurationRoot) {
      base.Configure(options, configurationRoot);
    }
    // public void Configure(JsonSerializerSettings options) {
    //   base.Configure(options);
    // }
    
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
