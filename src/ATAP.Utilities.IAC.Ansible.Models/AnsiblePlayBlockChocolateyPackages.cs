
using System.Collections.Generic;

namespace ATAP.Utilities.IAC.Ansible {
  public class AnsiblePlayBlockChocolateyPackages : IAnsiblePlayBlockChocolateyPackages {
    public string Name { get; set; }
    public string Version { get; set; }
    public bool Prerelease { get; set; }
    public List<string> AddedParameters { get; set; }

    public AnsiblePlayBlockChocolateyPackages(string name, string version, bool prerelease, List<string> addedParameters) {
      Name = name;
      Version = version;
      Prerelease = prerelease;
      AddedParameters = addedParameters;
    }
  }
}
