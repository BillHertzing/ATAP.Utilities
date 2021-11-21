using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

using Microsoft.Extensions.Configuration;

using ATAP.Utilities.Serializer;

using static ATAP.Utilities.Collection.Extensions;


namespace ATAP.Utilities.Serializer.Shim.SystemTextJson {

  public class Serializer : SerializerConfigurableAbstract {
    //private List<JsonConverter> JsonConvertersCache { get; set; }
    // attribution: [Avoid performance issues with JsonSerializer by reusing the same Options instance](https://www.meziantou.net/avoid-performance-issue-with-jsonserializer-by-reusing-the-same-instance-of-json.htm)
    public Serializer() : this((ISerializerOptionsAbstract)new SerializerOptions(new JsonSerializerOptions()), null) { }

    public Serializer(IConfigurationRoot? configurationRoot) : this((ISerializerOptionsAbstract)new SerializerOptions(new JsonSerializerOptions()), configurationRoot) { }

    public Serializer(ISerializerOptionsAbstract options) : this(options, null) { }

    public Serializer(ISerializerOptionsAbstract options, IConfigurationRoot? configurationRoot = default) : base(options, configurationRoot) { }

    public Serializer(List<JsonConverter> jsonConverters) : this((ISerializerOptionsAbstract)new SerializerOptions(new JsonSerializerOptions()), null) {
      ((JsonSerializerOptions)(Options.ShimSpecificOptions)).PopulateConverters(jsonConverters);
    }

    // public Serializer(JsonSerializerSettings options) {
    //   this.Configure(options);
    // }

    // public override void Configure() {
    //   this.Configure((ISerializerOptionsAbstract)new SerializerOptions(new JsonSerializerOptions()), null);

    //   // ToDo: Add a method that returns a specific list of JsonConverter which would be the default for ATAP utilities
    //   //JsonConvertersCache = new List<JsonConverter>() {
    //   // DictionaryJsonConverterFactory.Default
    //   // };
    // }
    // public override void Configure(IConfigurationRoot? configurationRoot) {
    //   // Store the configurationRoot in the serializer
    //   // Configure the serializer according to any settings in the configurationRoot
    //   base.Configure((ISerializerOptionsAbstract)new SerializerOptions(new JsonSerializerOptions()), configurationRoot);
    // }
    // public override void Configure(ISerializerOptionsAbstract options) {
    //   base.Configure(options);
    // }
    // public override void Configure(ISerializerOptionsAbstract options, IConfigurationRoot? configurationRoot) {
    //   base.Configure(options, configurationRoot);
    //   //JsonConvertersCache = new List<JsonConverter>();
    //   //JsonConvertersCache.AddRange(((JsonSerializerOptions)Options).ShimSpecificOptions.Converters)
    //   //((JsonSerializerOptions)Options).ShimSpecificOptions.PopulateConverters(JsonConvertersCache);
    // }
    public override string Serialize(object obj) {
      return JsonSerializer.Serialize(obj, (JsonSerializerOptions)Options.ShimSpecificOptions);
    }
    public override T Deserialize<T>(string str) {
      return JsonSerializer.Deserialize<T>(str, (JsonSerializerOptions)Options.ShimSpecificOptions);
    }
    public override string Serialize(object obj, ISerializerOptionsAbstract options) {
      return JsonSerializer.Serialize(obj, (JsonSerializerOptions)options.ShimSpecificOptions);
    }
    public override T Deserialize<T>(string str, ISerializerOptionsAbstract options) {
      return JsonSerializer.Deserialize<T>(str, (JsonSerializerOptions)options.ShimSpecificOptions);
    }


    // public void Configure(JsonSerializerOptions serializerOptions) {
    //   Options = new SerializerOptions(serializerOptions);
    // }
    // public void Configure(List<JsonConverter> jsonConverters) {
    //   Options = new SerializerOptions(new JsonSerializerOptions());
    //   // ToDo: Null Check
    //   //JsonConvertersCache = jsonConverters;
    //  //((JsonSerializerOptions)Options.ShimSpecificOptions).PopulateConverters(jsonConverters);
    // foreach (var converter in jsonConverters) {
    //   ((JsonSerializerOptions)Options.ShimSpecificOptions).Converters.Add(converter);
    //  }
    // }
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
}
