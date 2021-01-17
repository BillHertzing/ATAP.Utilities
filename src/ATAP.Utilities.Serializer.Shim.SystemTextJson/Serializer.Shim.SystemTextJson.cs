using System;
using System.Collections;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Serializer.Shim.SystemTextJson {

  public class Serializer : ISerializer {
    private List<JsonConverterFactory> JsonConverterFactorysCache { get; set; }
    private List<JsonConverter> JsonConvertersCache { get; set; }
    private JsonSerializerOptions JsonSerializerOptionsCurrent { get; set; }
    public Serializer() {
      this.Configure();
    }

    public string Serialize(object obj) {
      return JsonSerializer.Serialize(obj, JsonSerializerOptionsCurrent);
    }
    public string Serialize(object obj, ISerializerOptions options) {
      JsonSerializerOptions jsonSerializerOptions = ConvertOptions(options);
      return JsonSerializer.Serialize(obj, jsonSerializerOptions);
    }
    public T Deserialize<T>(string str) {
      return JsonSerializer.Deserialize<T>(str, JsonSerializerOptionsCurrent);
    }
    public T Deserialize<T>(string str, ISerializerOptions options) {
      JsonSerializerOptions jsonSerializerOptions = ConvertOptions(options);
      return JsonSerializer.Deserialize<T>(str, jsonSerializerOptions);
    }

    public void Configure() {
      JsonConverterFactorysCache = new List<JsonConverterFactory>();
      JsonConvertersCache = new List<JsonConverter>();
      JsonSerializerOptionsCurrent = new JsonSerializerOptions {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
      };
      PopulateConverters(JsonSerializerOptionsCurrent, JsonConvertersCache, JsonConverterFactorysCache);
    }
    public void Configure(ISerializerOptions options) {
      JsonSerializerOptionsCurrent = ConvertOptions(options);
    }
    private JsonSerializerOptions ConvertOptions(
        bool allowTrailingCommas = false
      , bool ignoreNullValues = false
      , bool writeIndented = false
    ) {
      JsonSerializerOptions jsonSerializerOptions = new() {
        AllowTrailingCommas = allowTrailingCommas,
        IgnoreNullValues = ignoreNullValues,
        WriteIndented = writeIndented,
      };
      PopulateConverters(jsonSerializerOptions, JsonConvertersCache, JsonConverterFactorysCache);
      return jsonSerializerOptions;

    }
    private JsonSerializerOptions ConvertOptions(ISerializerOptions options) {
      JsonSerializerOptions jsonSerializerOptions = new() {
        AllowTrailingCommas = options.AllowTrailingCommas,
        IgnoreNullValues = options.IgnoreNullValues,
        WriteIndented = options.WriteIndented
      };
      PopulateConverters(jsonSerializerOptions, JsonConvertersCache, JsonConverterFactorysCache);
      return jsonSerializerOptions;
    }
    private static void PopulateConverters(JsonSerializerOptions jsonSerializerOptions, List<JsonConverter> jsonConverters = default, List<JsonConverterFactory> jsonConverterFactorys = default) {
      jsonSerializerOptions.Converters.Clear();
      foreach (var converter in jsonConverters) {
        jsonSerializerOptions.Converters.Add(converter);
      }
      foreach (var converterFactory in jsonConverterFactorys) {
        jsonSerializerOptions.Converters.Add(converterFactory);
      }
    }
    // ToDo: enhancement to allow a loaded modules to ask for additional modules to be loaded
    // ToDo: another method with a signature that allows for a IDictionary<Type, ILoaderShimNameAndNamespace>
    // ToDo: another method with a signature that allows for a IDictionary<Type, ILoaderShimNameAndNamespaceConfigurationRootKeyAndDefaultValue>
    public static void LoadSubModules(ISerializer instance, Type subModuleType, string subModuleShimName, string subModuleShimNamespace, string[] relativePathsToProbe) {
      switch (subModuleType) {
        case Type jsonConverterType when jsonConverterType == typeof(JsonConverter): {
            LoadJsonConverters(subModuleShimName, subModuleShimNamespace, relativePathsToProbe);
            break;
          }
        case Type jsonConverterFactoryType when jsonConverterFactoryType == typeof(JsonConverterFactory): {
            LoadJsonConverterFactorys(subModuleShimName, subModuleShimNamespace, relativePathsToProbe);
            break;
          }
        default: {
            throw new ArgumentException($"toDo:Put in string localizer for argument {nameof(subModuleType)} value is unsupported");
          }
      }
    }

    public  void LoadJsonConverters(string jsonConverterShimName, string jsonConverterShimNamespace, string[] relativePathsToProbe) {
      // Load all Plugin Assemblies with a name that matches the serializerShimName
      // get all types that implement JsonConverter
      // cache them and also add them to the JsonSerializerOptionsCurrent
      //JsonConverterFactorysCache.Add();
    }
    public  void LoadJsonConverterFactorys(string jsonConverterFactoryShimName, string jsonConverterFactoryShimNamespace, string[] relativePathsToProbe) {
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
