using System;
using System.Collections.Generic;
using Newtonsoft.Json;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Serializer;

using static ATAP.Utilities.Collection.Extensions;

namespace ATAP.Utilities.Serializer.Shim.Newtonsoft {

  public class Serializer : SerializerConfigurableAbstract {
    public Serializer() : this((ISerializerOptionsAbstract)new SerializerOptions(new JsonSerializerSettings()), null) { }

    public Serializer(IConfigurationRoot? configurationRoot) : this((ISerializerOptionsAbstract)new SerializerOptions(new JsonSerializerSettings()), configurationRoot) { }

    public Serializer(ISerializerOptionsAbstract options) : this(options, null) { }

    public Serializer(ISerializerOptionsAbstract options, IConfigurationRoot? configurationRoot = default) : base(options, configurationRoot) { }

    // public Serializer(List<JsonConverter> jsonConverters) : this((ISerializerOptionsAbstract)new SerializerOptions(new JsonSerializerSettings()), null) {
    //   ((JsonSerializerSettings)(Options.ShimSpecificOptions)).PopulateConverters(jsonConverters);
    // }
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

    //JsonConvertersCache = new List<JsonConverter>();
    //JsonConvertersCache.AddRange(((JsonSerializerOptions)Options).ShimSpecificOptions.Converters)
    //((JsonSerializerOptions)Options).ShimSpecificOptions.PopulateConverters(JsonConvertersCache);

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
