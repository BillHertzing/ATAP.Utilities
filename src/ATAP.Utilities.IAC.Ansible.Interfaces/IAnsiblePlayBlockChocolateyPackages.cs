using System.Collections.Generic;

namespace ATAP.Utilities.IAC.Ansible {

  // Interface for AnsiblePlayBlockChocolateyPackages, derived from IAnsiblePlayBlockCommon
  public interface IAnsiblePlayBlockChocolateyPackages : IAnsiblePlayBlockCommon {
    string Version { get; set; }
    bool Prerelease { get; set; }
    List<string> AddedParameters { get; set; }
  }
}
