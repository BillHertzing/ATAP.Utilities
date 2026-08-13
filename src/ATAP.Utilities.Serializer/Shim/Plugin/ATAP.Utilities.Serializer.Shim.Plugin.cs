using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

using ATAP.Utilities.Loader;

namespace ATAP.Utilities.Serializer.Shim.Plugin;

/// <summary>
/// A System.Text.Json serializer whose converter set can be extended by the dynamic loader.
/// </summary>
public sealed class Serializer : SerializerConfigurableAbstract, ILoadDynamicSubModules {
  private readonly List<JsonConverter> jsonConvertersCache = new();

  public Serializer()
    : this(new SerializerOptions()) { }

  public Serializer(ISerializerOptionsAbstract options)
    : base(new SerializerOptions(options)) {
    CacheConfiguredConverters();
  }

  public Serializer(JsonSerializerOptions options)
    : base(new SerializerOptions(options)) {
    CacheConfiguredConverters();
  }

  public Serializer(List<JsonConverter> jsonConverters)
    : this(new JsonSerializerOptions()) {
    ArgumentNullException.ThrowIfNull(jsonConverters);
    foreach (var converter in jsonConverters) {
      AddConverter(converter);
    }
  }

  public override string Serialize(object obj) =>
    JsonSerializer.Serialize(obj, GetJsonSerializerOptions(Options));

  public override T Deserialize<T>(string str) =>
    JsonSerializer.Deserialize<T>(str, GetJsonSerializerOptions(Options))!;

  public override string Serialize(object obj, ISerializerOptionsAbstract options) =>
    JsonSerializer.Serialize(obj, GetJsonSerializerOptions(options));

  public override T Deserialize<T>(string str, ISerializerOptionsAbstract options) =>
    JsonSerializer.Deserialize<T>(str, GetJsonSerializerOptions(options))!;

  /// <summary>
  /// Describes dynamically loadable JSON converter submodules.
  /// </summary>
  public IDictionary<Type, IDynamicSubModulesInfo> GetDynamicSubModulesInfo() =>
    new Dictionary<Type, IDynamicSubModulesInfo> {
      [typeof(JsonConverter)] = new DynamicSubModulesInfo {
        DynamicGlobAndPredicate = new DynamicGlobAndPredicate {
          Glob = new ATAP.Utilities.FileIO.Glob {
            Pattern = @".\Plugins\*JsonConverter.Shim.SystemTextJson.dll"
          },
          Predicate = type =>
            typeof(JsonConverter).IsAssignableFrom(type)
            && !type.IsAbstract
            && type.Namespace == "ATAP.Utilities.Serializer.Shim.SystemTextJson"
        },
        Function = instance => AddConverter((JsonConverter)instance)
      }
    };

  private void CacheConfiguredConverters() {
    foreach (var converter in GetJsonSerializerOptions(Options).Converters) {
      jsonConvertersCache.Add(converter);
    }
  }

  private void AddConverter(JsonConverter converter) {
    ArgumentNullException.ThrowIfNull(converter);
    jsonConvertersCache.Add(converter);
    var updatedOptions = new JsonSerializerOptions(GetJsonSerializerOptions(Options));
    updatedOptions.Converters.Add(converter);
    Options = new SerializerOptions(updatedOptions);
  }

  private static JsonSerializerOptions GetJsonSerializerOptions(ISerializerOptionsAbstract options) {
    ArgumentNullException.ThrowIfNull(options);
    return options.ShimSpecificOptions as JsonSerializerOptions
      ?? throw new ArgumentException(
        $"{nameof(options)} must contain {nameof(JsonSerializerOptions)}.",
        nameof(options));
  }
}
