public class AnsibleTask : IAnsibleTask
{
  public List<Play> Plays { get; }

  public AnsibleTask(IEnumerable<Play> plays)
  {
    Plays = new List<Play>(plays);
  }

  public AnsibleTask()
  {
    Plays = new List<Play>();
  }

  public static AnsibleTask ConvertFromYaml(string yamlContent)
  {
    var deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
    return deserializer.Deserialize<AnsibleTask>(yamlContent);
  }

  public string ConvertToYaml()
  {
    var serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
    return serializer.Serialize(this);
  }
}
