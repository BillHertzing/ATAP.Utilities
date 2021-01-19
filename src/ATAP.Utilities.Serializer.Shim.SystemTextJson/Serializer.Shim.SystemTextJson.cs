using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;
// This module, if loaded dynamically, has submodules which must be loaded dynamically as well
// ToDo: make a separate assembly for subloading, to be included only if the code will be loaded dynamically
using ATAP.Utilities.Loader;
using ATAP.Utilities.FileIO;
using System.Reflection;

using static ATAP.Utilities.Collection.Extensions;

namespace ATAP.Utilities.Serializer.Shim.SystemTextJson {

  public static partial class Extensions {
    public static JsonSerializerOptions PopulateConverters(this JsonSerializerOptions jsonSerializerOptions, List<JsonConverter> jsonConverters = default) {
      // ToDo: Add parameter checking
      jsonSerializerOptions.Converters.Clear();
      foreach (var converter in jsonConverters) {
        jsonSerializerOptions.Converters.Add(converter);
      }
      return jsonSerializerOptions;
    }
    public static JsonSerializerOptions Configure(this JsonSerializerOptions jsonSerializerOptions, ISerializerOptions options) {
      jsonSerializerOptions.ConvertOptions(options);
      return jsonSerializerOptions;
    }
    public static JsonSerializerOptions ConvertOptions(this JsonSerializerOptions jsonSerializerOptions, ISerializerOptions options, List<JsonConverter> jsonConverters = default) {
      jsonSerializerOptions.AllowTrailingCommas = options.AllowTrailingCommas;
      jsonSerializerOptions.IgnoreNullValues = options.IgnoreNullValues;
      jsonSerializerOptions.WriteIndented = options.WriteIndented;
      jsonSerializerOptions.PopulateConverters(jsonConverters);
      return jsonSerializerOptions;
    }
    public static JsonSerializerOptions ConvertOptions(this JsonSerializerOptions jsonSerializerOptions
      , bool allowTrailingCommas = default
      , bool ignoreNullValues = default
      , bool writeIndented = default
      , List<JsonConverter> jsonConverters = default
      ) {
      jsonSerializerOptions.AllowTrailingCommas = allowTrailingCommas;
      jsonSerializerOptions.IgnoreNullValues = ignoreNullValues;
      jsonSerializerOptions.WriteIndented = writeIndented;
      jsonSerializerOptions.Converters.Clear();
      jsonSerializerOptions.Converters.AddRange(jsonConverters);
      return jsonSerializerOptions;
    }

  }
  public class Serializer : ISerializer, ILoadSubModules {
    private List<JsonConverter> JsonConvertersCache { get; set; }
    // attribution: [Avoid performance issues with JsonSerializer by reusing the same JsonSerializerOptions instance](https://www.meziantou.net/avoid-performance-issue-with-jsonserializer-by-reusing-the-same-instance-of-json.htm)
    private JsonSerializerOptions JsonSerializerOptionsCurrent { get; set; }
    public Serializer() {
      this.Configure();
    }

    public string Serialize(object obj) {
      return JsonSerializer.Serialize(obj, JsonSerializerOptionsCurrent);
    }
    public string Serialize(object obj, ISerializerOptions options) {
      JsonSerializerOptions jsonSerializerOptions = new JsonSerializerOptions().ConvertOptions(options);
      return JsonSerializer.Serialize(obj, jsonSerializerOptions);
    }
    public T Deserialize<T>(string str) {
      return JsonSerializer.Deserialize<T>(str, JsonSerializerOptionsCurrent);
    }
    public T Deserialize<T>(string str, ISerializerOptions options) {
      JsonSerializerOptions jsonSerializerOptions = new JsonSerializerOptions().ConvertOptions(options);
      return JsonSerializer.Deserialize<T>(str, jsonSerializerOptions);
    }

    // ToDo: add a Configure which has default values of the JsonSerializerOptionsCurrent should come from an IConfiguration object, and keys/default values should come from a StringConstants
    // ToDo: ConvertOptions should be expanded to include a set of extensions for JsonSerializerOptions class to promote reuse of the instance
    public void Configure() {
      JsonConvertersCache = new List<JsonConverter>();
      JsonSerializerOptionsCurrent = new JsonSerializerOptions {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
      };
      JsonSerializerOptionsCurrent.PopulateConverters(JsonConvertersCache);
    }
    public void Configure(ISerializerOptions options) {
      JsonSerializerOptionsCurrent = new JsonSerializerOptions().ConvertOptions(options);
    }
    private static void PopulateConverters(JsonSerializerOptions jsonSerializerOptions, List<JsonConverter> jsonConverters = default) {
      // ToDo: Add parameter checking
      jsonSerializerOptions.Converters.Clear();
      foreach (var converter in jsonConverters) {
        jsonSerializerOptions.Converters.Add(converter);
      }
    }
    // ToDo: enhancement to allow a loaded modules to ask for additional modules to be loaded
    // ToDo: another method with a signature that allows for a IDictionary<Type, ILoaderShimNameAndNamespace>
    // ToDo: another method with a signature that allows for a IDictionary<Type, ILoaderShimNameAndNamespaceConfigRootKeyAndDefaultValue>
    // public static void LoadSubModules(ISerializer instance, Type subModuleType, string subModuleShimName, string subModuleShimNamespace, string[] relativePathsToProbe) {
    //   switch (subModuleType) {
    //     case Type jsonConverterType when jsonConverterType == typeof(JsonConverter): {
    //         LoadJsonConverters(subModuleShimName, subModuleShimNamespace, relativePathsToProbe);
    //         break;
    //       }
    //     case Type jsonConverterFactoryType when jsonConverterFactoryType == typeof(JsonConverterFactory): {
    //         LoadJsonConverterFactorys(subModuleShimName, subModuleShimNamespace, relativePathsToProbe);
    //         break;
    //       }
    //     default: {
    //         throw new ArgumentException($"toDo:Put in string localizer for argument {nameof(subModuleType)} value is unsupported");
    //       }
    //   }
    // }

    // This module, if loaded dynamically, has submodules which must be loaded dynamically asa well
    // ToDo: make a separate assembly, to be included only if the code will be loaded dynamically
    class SubModulesInfo<Type> : ISubModulesInfo<Type> {
      public Glob Glob { get; }
      public Action<Type, object> Function { get; }
      public Predicate<Type> Pred { get; }
      public SubModulesInfo(Action<Type, object> function, Predicate<Type> pred) {
        // ToDo: validate parameters
        Function = function;
        Pred = pred;
      }

    }
    public IDictionary<Type, ISubModulesInfo<Type>> GetSubModulesInfo() {
      Dictionary<Type, ISubModulesInfo<Type>> subModulesInfoDictionary = new();
      // subModulesInfoDictionary[typeof(JsonConverter)] = new SubModulesInfo<JsonConverter>(
      //   new Action<Type, object>((x, y) => { return; }),
      //   new Predicate<Type>(
      //     _type => {
      //       return
      //         typeof(JsonConverter).IsAssignableFrom(_type)
      //         && !_type.IsAbstract
      //         && _type.Namespace == "ATAP.Utilities.Serializer.Shim.SystemTextJson"
      //       ;
      //     }
      //   )
      // );
      return subModulesInfoDictionary;
    }

    public void LoadJsonConverters(string jsonConverterShimName, string jsonConverterShimNamespace, string[] relativePathsToProbe) {
      // Load all Plugin Assemblies with a name that matches the serializerShimName
      // get all types that implement JsonConverter
      // cache them and also add them to the JsonSerializerOptionsCurrent
      //JsonConverterFactorysCache.Add();
    }
    public void LoadJsonConverterFactorys(string jsonConverterFactoryShimName, string jsonConverterFactoryShimNamespace, string[] relativePathsToProbe) {
      // Load all Plugin Assemblies with a name that matches the serializerShimName
      // get all types that implement JsonConverterFactory (aka the open generic JsonConverter<T>)
      // cache them and also add them to the JsonSerializerOptionsCurrent
      //JsonConverterFactorysCache.Add();
    }
  }

  //  public class StronglyTypedIDsConverter
  //         : JsonConverter<Id<T>>
  //     {
  //         public override object Read(
  //             ref Utf8JsonReader reader,
  //             Type typeToConvert,
  //             JsonSerializerOptions options) => reader.TokenType switch
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
  //             JsonSerializerOptions options) =>
  //             throw new InvalidOperationException("Should not get here.");
  //     }

  //   public abstract class SerializerConverterFactory<T> {
  //     public abstract bool CanConvert(Type typeToConvert);
  //     public abstract JsonConverter<T> CreateConverter(
  //                 Type type,
  //                 JsonSerializerOptions options);
  //   }

  //   public abstract class SerializerConverter<T> : JsonConverter<T> {

  //   }

}
