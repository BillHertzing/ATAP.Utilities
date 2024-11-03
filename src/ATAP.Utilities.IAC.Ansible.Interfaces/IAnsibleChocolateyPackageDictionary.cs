namespace ATAP.Utilities.IAC.Ansible
{
  public interface IAnsibleChocolateyPackage
  {
    string Name { get; set; }
    string Version { get; set; }
    string AdditionalParameters { get; set; }
    IGlobalSettings GlobalSettings { get; set; }
    IRegistrySettings RegistrySettings { get; set; }
    IWindowsFeatures WindowsFeatures { get; set; }
    IPKICertificates PKICertificates { get; set; }
    IScheduledJobs ScheduledJobs { get; set; }
    string Notes { get; set; }

    string[] PowershellModules { get; set; }

  }
}
