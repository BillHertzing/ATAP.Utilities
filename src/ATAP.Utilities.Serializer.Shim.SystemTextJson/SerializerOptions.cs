

using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Serializer.Shim.SystemTextJson {

  public class SerializerOptions : ATAP.Utilities.Serializer.ISerializerOptionsAbstract {
    public object ShimSpecificOptions { get; set; }
    public SerializerOptions() {
      // uses the primitive type default for all Autoproperties (false for bool, null for objects and strings)
    }

    public SerializerOptions(ISerializerOptionsAbstract options) {
      ShimSpecificOptions = (JsonSerializerOptions)options.ShimSpecificOptions;
    }

    public SerializerOptions(JsonSerializerOptions jsonSerializerOptions) {
      ShimSpecificOptions = jsonSerializerOptions;
    }
  }
}
