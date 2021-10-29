using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

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
    // public static Options Configure(this Options jsonSerializerOptions, ISerializerOptions options) {
    //   jsonSerializerOptions.ConvertOptions(options);
    //   return jsonSerializerOptions;
    // }

    //ToDo: revisit - this would alllow a mismatch between the ShimSpecificOptions field values and the individual ones
    // public static Options ConvertOptions(this Options jsonSerializerOptions, ISerializerOptions options, List<JsonConverter> jsonConverters = default) {
    //   jsonSerializerOptions.AllowTrailingCommas = options.AllowTrailingCommas;
    //   jsonSerializerOptions.IgnoreNullValues = options.IgnoreNullValues;
    //   jsonSerializerOptions.WriteIndented = options.WriteIndented;
    //   jsonSerializerOptions.ShimSpecificOptions = options.ShimSpecificOptions;
    //   if (jsonConverters != null) {
    //     jsonSerializerOptions.PopulateConverters(jsonConverters);
    //   }
    //   return jsonSerializerOptions;
    // }
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
      if (jsonConverters != null) {
        jsonSerializerOptions.Converters.AddRange(jsonConverters);
      }
      return jsonSerializerOptions;
    }

  }
}
