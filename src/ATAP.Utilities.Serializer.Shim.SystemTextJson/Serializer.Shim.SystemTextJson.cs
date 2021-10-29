using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

using ATAP.Utilities.Serializer;
// This module, if loaded dynamically, has submodules which must be loaded dynamically as well
// ToDo: make a separate assembly for subloading, to be included only if the code will be loaded dynamically
#if NETCORE
using ATAP.Utilities.Loader;
using ATAP.Utilities.FileIO;
using System.Reflection;
#endif

using static ATAP.Utilities.Collection.Extensions;

namespace ATAP.Utilities.Serializer.Shim.SystemTextJson {

#if NETSTANDARD || NETCORE
  public class Serializer : ISerializer, ILoadDynamicSubModules {
#else
  public class Serializer : ISerializer {
#endif
    //private List<JsonConverter> JsonConvertersCache { get; set; }
    // attribution: [Avoid performance issues with JsonSerializer by reusing the same Options instance](https://www.meziantou.net/avoid-performance-issue-with-jsonserializer-by-reusing-the-same-instance-of-json.htm)
    public ISerializerOptions Options { get; set; }
    public Serializer() {
      this.Configure();
    }

    public Serializer(ISerializerOptions options) {
      this.Configure(options);
    }
    public Serializer(JsonSerializerOptions options) {
      this.Configure(options);
    }
    public Serializer(List<JsonConverter> jsonConverters) {
      this.Configure(jsonConverters);
    }

    public string Serialize(object obj) {
      return JsonSerializer.Serialize(obj, (JsonSerializerOptions)Options.ShimSpecificOptions);
    }
    public T Deserialize<T>(string str) {
      return JsonSerializer.Deserialize<T>(str, (JsonSerializerOptions)Options.ShimSpecificOptions);
    }
    public string Serialize(object obj, ISerializerOptions options) {
      return JsonSerializer.Serialize(obj, (JsonSerializerOptions)options.ShimSpecificOptions);
    }
    public T Deserialize<T>(string str, ISerializerOptions options) {
      return JsonSerializer.Deserialize<T>(str, (JsonSerializerOptions)options.ShimSpecificOptions);
    }

    // ToDo: add a Configure which has default values of the Options should come from an IConfiguration object, and keys/default values should come from a StringConstants
    public void Configure() {
      //
      Options = new SerializerOptions(new JsonSerializerOptions());
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
    public void Configure(JsonSerializerOptions jsonSerializerOptions) {
      Options = new SerializerOptions(jsonSerializerOptions);
    }
    public void Configure(List<JsonConverter> jsonConverters) {
      Options = new SerializerOptions(new JsonSerializerOptions());
      // ToDo: Null Check
      //JsonConvertersCache = jsonConverters;
      //((JsonSerializerOptions)Options.ShimSpecificOptions).PopulateConverters(jsonConverters);
      foreach (var converter in jsonConverters) {
        ((JsonSerializerOptions)Options.ShimSpecificOptions).Converters.Add(converter);
      }
    }

#if NETSTANDARD || NETCORE
    // This module, if loaded dynamically, has submodules which must be loaded dynamically as well
    // ToDo: make a separate assembly, to be included only if the code will be loaded dynamically
    /// <summary>
    /// returns a dictionary, keyed by type, with a DynamicSubModulesInfo for each type
    /// </summary>
    /// <returns>IDictionary<Type, ISubModulesInfo></returns>
    public IDictionary<Type, IDynamicSubModulesInfo> GetDynamicSubModulesInfo() {
      Dictionary<Type, IDynamicSubModulesInfo> dynamicSubModulesInfoDictionary = new();
      dynamicSubModulesInfoDictionary[typeof(JsonConverter)] = new DynamicSubModulesInfo() {
        DynamicGlobAndPredicate = new DynamicGlobAndPredicate() {
          Glob = new Glob() {
            Pattern = ".\\Plugins\\*JsonConverter.Shim.SystemTextJson.dll"
          },
          Predicate = new Predicate<Type>(
          _type => {
            return
              typeof(JsonConverter).IsAssignableFrom(_type)
              && !_type.IsAbstract
              && _type.Namespace == "ATAP.Utilities.Serializer.Shim.SystemTextJson"
            ;
          }
         )
        },
        Function = new Action<object>((instance) => { JsonConvertersCache.Add((JsonConverter)instance); return; })
      };
      return dynamicSubModulesInfoDictionary;
    }

    public void LoadJsonConverters(string jsonConverterShimName, string jsonConverterShimNamespace, string[] relativePathsToProbe) {
      // Load all Plugin Assemblies with a name that matches the serializerShimName
      // get all types that implement JsonConverter
      // cache them and also add them to the JsonSerializerOptions
      //JsonConverterFactorysCache.Add();
    }
    public void LoadJsonConverterFactorys(string jsonConverterFactoryShimName, string jsonConverterFactoryShimNamespace, string[] relativePathsToProbe) {
      // Load all Plugin Assemblies with a name that matches the serializerShimName
      // get all types that implement JsonConverterFactory (aka the open generic JsonConverter<T>)
      // cache them and also add them to the JsonSerializerOptions
      //JsonConverterFactorysCache.Add();
    }
#endif
  }
  //  public class StronglyTypedIDConverter
  //         : JsonConverter<Id<T>>
  //     {
  //         public override object Read(
  //             ref Utf8JsonReader reader,
  //             Type typeToConvert,
  //             Options options) => reader.TokenType switch
  //             {
  //                 JsonTokenType.True => true,
  //                 JsonTokenType.False => false,
  //                 JsonTokenType.Number when reader.TryGetInt64(out long l) => l,
  //                 JsonTokenType.Number => reader.GetDouble(),
  //                 JsonTokenType.String when reader.TryGetDateTime(out DateTime datetime) => datetime,
  //                 JsonTokenType.String => reader.GetString(),
  //                 _ => JsonDocument.ParseValue(ref reader).RootElement.Clone()
  //             };

  //         public override void Write(
  //             Utf8JsonWriter writer,
  //             object objectToWrite,
  //             Options options) =>
  //             throw new InvalidOperationException("Should not get here.");
  //     }

  //   public abstract class SerializerConverterFactory<T> {
  //     public abstract bool CanConvert(Type typeToConvert);
  //     public abstract JsonConverter<T> CreateConverter(
  //                 Type type,
  //                 Options options);
  //   }

  //   public abstract class SerializerConverter<T> : JsonConverter<T> {

  //   }

}
