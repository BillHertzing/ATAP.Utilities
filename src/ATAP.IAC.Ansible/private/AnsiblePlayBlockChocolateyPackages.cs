  public class ChocolateyPackageArguments : IChocolateyPackageArguments
  {
    public string Name { get; set; }

    public ChocolateyPackageArguments() { }

    public ChocolateyPackageArguments(string name)
    {
      Name = name;
    }

    public static ChocolateyPackageArguments  ConvertFromYaml(string yamlContent)
    {
      var deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
      return deserializer.Deserialize<ChocolateyPackageArguments>(yamlContent);
    }

    public string ConvertToYaml()
    {
      var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
      return serializer.Serialize(this);
    }

  }
