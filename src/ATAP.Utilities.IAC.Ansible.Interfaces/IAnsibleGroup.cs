using System.Collections.Generic;

namespace ATAP.Utilities.IAC.Ansible {
  public interface IAnsibleGroup {
    AnsibleGroupNamesEnum Name { get; }
    //IAnsibleChocolateyPackage ChocolateyPackages { get; }
    //#string[] PowershellModuleNames { get; }
    //string[] NPMPackageNames { get; }
    IDictionary<AnsibleRoleNamesEnum, IAnsibleRole> AnsibleRoles { get; }
    string[] AnsibleRoleNames { get; }
    //string[] RegistrySettingsNames { get; }
    //string[] GlobalSettingsNames { get; }
    //string[] WindowsFeatureNames { get; }
    //string[] PKICertificatesNames { get; }

    IList<IAnsiblePlayBlockCommon> Items { get; set; }
  }
}
