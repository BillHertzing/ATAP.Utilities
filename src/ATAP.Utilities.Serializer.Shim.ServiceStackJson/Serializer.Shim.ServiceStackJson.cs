using ServiceStack.Text;

using System;

namespace ATAP.Utilities.Serializer {
  public class Serializer : ISerializer {
    private ServiceStack.Text.Config JsonSerializerOptionsCurrent { get; set; }
    public Serializer() {
      this.Configure();
    }

    public string Serialize(object obj) {
      return this.Serialize(obj, JsonSerializerOptionsCurrent);
    }

    public string Serialize(object obj, ISerializerOptions options) {
      var jsonSerializerOptions = ConvertOptions(options);
      return this.Serialize(obj, jsonSerializerOptions);
    }
    public string Serialize(object obj, ServiceStack.Text.Config options) {
      //ToDo: set servicestack options to the jsonSerializerOptions
      return ServiceStack.Text.JsonSerializer.SerializeToString(obj);
    }

    public T Deserialize<T>(string str) {
      return this.Deserialize<T>(str, JsonSerializerOptionsCurrent);
    }

    public T Deserialize<T>(string str, ISerializerOptions options) {
      var jsonSerializerOptions = ConvertOptions(options);
      return this.Deserialize<T>(str, jsonSerializerOptions);
    }

    public T Deserialize<T>(string str, ServiceStack.Text.Config options) {
      // ToDo: update the servicestack config with options
      return ServiceStack.Text.JsonSerializer.DeserializeFromString<T>(str);
    }

    public void Configure() {
      JsConfig.TextCase = TextCase.PascalCase;
      JsConfig.TreatEnumAsInteger = true;
      JsConfig.ExcludeDefaultValues = false;
      JsConfig.IncludeNullValues = true;
      JsConfig.ExcludeTypeInfo = true;
      //    new EnumSerializerConfigurator()
      //.WithAssemblies(AppDomain.CurrentDomain.GetAssemblies())
      //.WithNamespaceFilter(ns => ns.StartsWith("ATAP"))
      //.Configure();
    }
    
    public void Configure() {
      JsonSerializerOptionsCurrent = new JsonSerializerOptions {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
      };
    }
    public void Configure(ISerializerOptions options) {
      JsonSerializerOptionsCurrent = ConvertOptions(options);
    }
    public void Configure(
        bool allowTrailingCommas = false
      , bool writeIndented = false
      , bool ignoreNullValues = false
    ) {
      JsonSerializerOptionsCurrent = ConvertOptions(allowTrailingCommas, writeIndented, ignoreNullValues);
    }

    private JsonSerializerOptions ConvertOptions(
        bool allowTrailingCommas = false
      , bool ignoreNullValues = false
      , bool writeIndented = false
    ) {
      return new JsonSerializerOptions {
        AllowTrailingCommas = allowTrailingCommas,
        IgnoreNullValues = ignoreNullValues,
        WriteIndented = writeIndented,
      };
    }
    private JsonSerializerOptions ConvertOptions(ISerializerOptions options) {
      return new JsonSerializerOptions {
        AllowTrailingCommas = options.AllowTrailingCommas,
        IgnoreNullValues = options.IgnoreNullValues,
        WriteIndented = options.WriteIndented
      };
    }
  }

  public class SerializerOptions : ISerializerOptions {
    public bool AllowTrailingCommas { get; set; }
    public bool WriteIndented { get; set; }
    public bool IgnoreNullValues { get; set; }
  }
}
