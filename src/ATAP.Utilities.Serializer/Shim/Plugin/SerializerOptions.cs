

using System;
using System.Text.Json;

using ATAP.Utilities.Serializer;

namespace ATAP.Utilities.Serializer.Shim.Plugin {

  public sealed class SerializerOptions : SerializerOptionsAbstract {
    public SerializerOptions() : base(new JsonSerializerOptions()) { }

    public SerializerOptions(ISerializerOptionsAbstract options)
      : base(GetJsonSerializerOptions(options)) { }

    public SerializerOptions(JsonSerializerOptions jsonSerializerOptions)
      : base(jsonSerializerOptions) { }

    private static JsonSerializerOptions GetJsonSerializerOptions(ISerializerOptionsAbstract options) {
      ArgumentNullException.ThrowIfNull(options);
      return options.ShimSpecificOptions as JsonSerializerOptions
        ?? throw new ArgumentException(
          $"{nameof(options)} must contain {nameof(JsonSerializerOptions)}.",
          nameof(options));
    }
  }
}
