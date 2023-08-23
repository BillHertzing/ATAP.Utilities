  public class RegistrySettingsArgument : IRegistrySettingsArgument
  {
    public string Purpose { get; set; }
    public string Data { get; set; }
    public string Type { get; set; }
    public string Path { get; set; }

    public RegistrySettingsArgument() { }

    public RegistrySettingsArgument(string purpose, string data, string type, string path)
    {
      Purpose = purpose;
      Data = data;
      Type = type;
      Path = path;
    }

    public static RegistrySettingsArgument  ConvertFromYaml(string yamlContent)
    {
      var deserializer = new DeserializerBuilder().Build();
      return deserializer.Deserialize<RegistrySettingsArgument>(yamlContent);
    }

    public string ConvertToYaml()

    {
      var serializer = new SerializerBuilder().Build();
      return serializer.Serialize(this);
    }

    public static RegistrySettingsArgument Create(string purpose, string data, string type, string path)
    {
      return new RegistrySettingsArgument
      {
        Purpose = purpose,
        Data = data,
        Type = type,
        Path = path
      };
    }
  }

