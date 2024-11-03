namespace ATAP.Utilities.IAC.Ansible
{
  public interface IAnsibleGroup
  {
    AnsibleGroupEnum Name { get; set; }
    IAnsibleChocolateyPackageDictionary ChocolateyPackages { get; }
    string[] PowershellModuleNames
    string[] NPMPackageNames
    string[] AnsibleRoleNames
    string[] RegistrySettingsNames
    string[] GlobalSettingsNames
    string[] WindowsFeatureNames

    string[] PKICertificatesNames


    List<IAnsiblePlayBlockCommon> Items { get; set; }
  }
}
