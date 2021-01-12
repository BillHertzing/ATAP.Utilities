using Newtonsoft.Json;

using System;

namespace ATAP.Utilities.Serializer.Shim.Newtonsoft {
  public class Serializer : ISerializer {
    private JsonSerializerSettings JsonSerializerSettingsCurrent { get; set; }
    public Serializer() {
      this.Configure();
    }

    public string Serialize(object obj) {
      // ToDo: based on JsonSerializerSettingsCurrent WriteIndented property,
      //   call either the SerializeObject method, or one that
      return JsonConvert.SerializeObject(obj);
    }
    public string Serialize(object obj, ISerializerOptions options) {
      JsonSerializerSettings jsonSerializerSettings = ConvertOptions(options);
      Formatting formatting = options.WriteIndented ? Formatting.Indented : Formatting.None;
      return JsonConvert.SerializeObject(obj, formatting, jsonSerializerSettings);
    }

    public T Deserialize<T>(string str) {
      return JsonConvert.DeserializeObject<T>(str);
    }
    public T Deserialize<T>(string str, ISerializerOptions options) {
      JsonSerializerSettings jsonSerializerSettings = ConvertOptions(options);
      return JsonConvert.DeserializeObject<T>(str, jsonSerializerSettings);
    }

    public void Configure() {
      JsonSerializerSettingsCurrent = new JsonSerializerSettings();// Func<JsonSerializerSettings>
      // ToDo: newtonsoft configuration for PascalCase
      // ToDo: newtonsoft configuration for Enumerations using Value (int)
      // ToDo: newtonsoft configuration to ensure default values are added to teh serialization (?maybe?)
    }
    public void Configure(ISerializerOptions options) {
      JsonSerializerSettingsCurrent = ConvertOptions(options);
    }
    // Convert an instance of the ATAP.Utilities.Serializer.Options class to a Newtonsoft JsonSerializerSettings instance
    private JsonSerializerSettings ConvertOptions(ISerializerOptions options) {
      return new JsonSerializerSettings {
        //ToDo: figure out workaround AllowTrailingCommas = options.AllowTrailingCommas,
        NullValueHandling = options.IgnoreNullValues ? NullValueHandling.Ignore : NullValueHandling.Include,
        // WriteIndented is handeled by Formatting Enumeration passed to Newtonsoft's Serialize method
      };
    }

  }
}
