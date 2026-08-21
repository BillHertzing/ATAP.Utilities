using System.Text.Json;
using ATAP.Utilities.StronglyTypedId.JsonConverter.Shim.SystemTextJson;

namespace ATAP.Utilities.StronglyTypedId.Tests {
  public static class Startup {
    public static JsonSerializerOptions CreateSerializerOptions() {
      var options = new JsonSerializerOptions();
      options.Converters.Add(new StronglyTypedIdJsonConverterFactory());
      return options;
    }
  }
}
