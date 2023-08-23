 public class Play
  {
    public string Name { get; set; }
    public List<AnsibleScriptBlock> AnsibleScriptBlocks { get; set; }

    public Play()
    {
      AnsibleScriptBlocks = new List<AnsibleScriptBlock>();
    }

    public static Play ConvertFromYaml(string yamlContent)
    {
      var deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
      return deserializer.Deserialize<Play>(yamlContent);
    }

    public string ConvertToYaml()
    {
      var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
      return serializer.Serialize(this);
    }
  }
