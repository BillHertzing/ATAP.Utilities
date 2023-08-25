  public class AnsiblePlayBlockChocolateyPackages : IAnsiblePlayBlockChocolateyPackages
  {
    public string Name { get; set; }
    public string Version { get; set; }
    public bool Prerelease { get; set; }
    public AnsiblePlayBlockChocolateyPackages(string name, string version, bool prerelease)
    {
      Name = name;
      Version = version;
      Prerelease = prerelease;
    }
  }
