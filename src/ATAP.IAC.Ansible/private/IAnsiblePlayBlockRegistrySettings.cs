  // Interface for AnsiblePlayBlockRegistrySettings, derived from IAnsiblePlayBlockCommon
  public interface IAnsiblePlayBlockRegistrySettings : IAnsiblePlayBlockCommon
  {
    string Path { get; set; }
    string Type { get; set; }
    string Value { get; set; }
  }
