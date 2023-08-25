  public class AnsiblePlayBlockRegistrySettings : IAnsiblePlayBlockRegistrySettings
  {
    public string Name { get; set; }
    public string Path { get; set; }
    public string Type { get; set; }
    public string Value { get; set; }
    public AnsiblePlayBlockRegistrySettings(string name, string path, string type, string value)
    {
      Name = name;
      Path = path;
      Type = type;
      Value = value;
    }
  }
