// Interface for AnsiblePlayBlockRegistrySettings, derived from IAnsiblePlayBlockCommon
public interface IAnsiblePlayBlockRegistrySettings : IAnsiblePlayBlockCommon
{
  string Purpose { get; set; }
  string Path { get; set; }
  string Type { get; set; }
  string Value { get; set; }
}