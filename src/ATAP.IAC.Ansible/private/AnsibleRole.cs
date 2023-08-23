public class AnsibleRole : IAnsibleRole
{
  public string Name { get; set; }
  public IAnsibleMeta AnsibleMeta { get; set; }
  public IAnsibleTask AnsibleTask { get; set; }

  public AnsibleRole()
  {
    AnsibleMeta = new AnsibleMeta();
    AnsibleTask = new AnsibleTask();
  }

  public AnsibleRole(string name, IAnsibleMeta ansibleMeta, IAnsibleTask ansibleTask)
  {
    Name = name;
    AnsibleMeta = ansibleMeta;
    AnsibleTask = ansibleTask;
  }
  public static AnsibleRole ConvertFromYaml(string yamlContent)
  {
    var deserializer = new DeserializerBuilder().Build();
    return deserializer.Deserialize<AnsibleRole>(yamlContent);
  }

  public string ConvertToYaml()
  {
    var serializer = new SerializerBuilder().Build();
    return serializer.Serialize(this);
  }
}
