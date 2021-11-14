

using System;
using System.Collections.Generic;
using Newtonsoft.Json;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Serializer.Shim.Newtonsoft {

  public class SerializerOptions : ATAP.Utilities.Serializer.ISerializerOptions {
    public object ShimSpecificOptions { get; set; }
    public SerializerOptions() {
      // uses the primitive type default for all Autoproperties (false for bool, null for objects and strings)
    }

    public SerializerOptions(ISerializerOptions options) {
      ShimSpecificOptions = (JsonSerializerSettings)options.ShimSpecificOptions;
    }

    public SerializerOptions(JsonSerializerSettings jsonSerializerSettings) {
      ShimSpecificOptions = jsonSerializerSettings;
    }
  }
}
