  // Interface for AnsiblePlayBlockChocolateyPackages, derived from IAnsiblePlayBlockCommon
  public interface IAnsiblePlayBlockChocolateyPackages : IAnsiblePlayBlockCommon
  {
    string Version { get; set; }
    bool Prerelease { get; set; }
  }
