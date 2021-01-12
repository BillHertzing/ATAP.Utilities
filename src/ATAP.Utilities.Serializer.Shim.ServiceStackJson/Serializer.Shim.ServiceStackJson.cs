using ServiceStack.Text;

using System;

namespace ATAP.Utilities.Serializer.Shim.ServiceStack {
  public class Serializer : ISerializer {
    private Config JsonSerializerOptionsCurrent { get; set; }
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
    public string Serialize(object obj, Config options) {
      //ToDo: set servicestack options to the jsonSerializerOptions
      return JsonSerializer.SerializeToString(obj);
    }

    public T Deserialize<T>(string str) {
      return this.Deserialize<T>(str, JsonSerializerOptionsCurrent);
    }

    public T Deserialize<T>(string str, ISerializerOptions options) {
      var jsonSerializerOptions = ConvertOptions(options);
      return this.Deserialize<T>(str, jsonSerializerOptions);
    }

    public T Deserialize<T>(string str, Config options) {
      // ToDo: update the servicestack config with options
      return JsonSerializer.DeserializeFromString<T>(str);
    }


    public void Configure() {
      JsonSerializerOptionsCurrent = new Config {
        TextCase = TextCase.CamelCase,
        TreatEnumAsInteger = true,
        ExcludeDefaultValues = false,
        IncludeNullValues = true,
        ExcludeTypeInfo = true,
        //    new EnumSerializerConfigurator()
        //.WithAssemblies(AppDomain.CurrentDomain.GetAssemblies())
        //.WithNamespaceFilter(ns => ns.StartsWith("ATAP"))
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

    private Config ConvertOptions(
        bool allowTrailingCommas = false
      , bool ignoreNullValues = false
      , bool writeIndented = false
    ) {
      return new Config {
        // AllowTrailingCommas = allowTrailingCommas,
        IncludeNullValues = !ignoreNullValues,
        //WriteIndented = writeIndented,
      };
    }
    private Config ConvertOptions(ISerializerOptions options) {
      return new Config {
        //AllowTrailingCommas = options.AllowTrailingCommas,
        IncludeNullValues = !options.IgnoreNullValues,
        //WriteIndented = options.WriteIndented
      };
    }
  }

  public class SerializerOptions : ISerializerOptions {
    public bool AllowTrailingCommas { get; set; }
    public bool WriteIndented { get; set; }
    public bool IgnoreNullValues { get; set; }
  }
}
