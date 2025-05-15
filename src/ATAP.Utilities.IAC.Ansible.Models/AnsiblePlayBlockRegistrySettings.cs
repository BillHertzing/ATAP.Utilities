namespace ATAP.Utilities.IAC.Ansible
{
  public class AnsiblePlayBlockRegistrySettings : IAnsiblePlayBlockRegistrySettings
  {
    public string Name { get; set; }
    public string Purpose { get; set; }
    public string Path { get; set; }
    public string Type { get; set; }
    public string Value { get; set; }
    public AnsiblePlayBlockRegistrySettings(string purpose, string name, string path, string type, string value)
    {
      Name = name;
      Purpose = purpose;
      Path = path;
      Type = type;
      Value = value;
    }
  }
}
