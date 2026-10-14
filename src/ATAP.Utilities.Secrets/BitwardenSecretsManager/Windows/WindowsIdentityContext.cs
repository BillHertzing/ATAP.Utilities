using System.Runtime.Versioning;
using System.Security.Principal;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

[SupportedOSPlatform("windows")]
public sealed class WindowsIdentityContext : IWindowsIdentityContext
{
  public string MachineName => Environment.MachineName.ToUpperInvariant();
  public string ProgramDataDirectory => Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
  public string SamAccountName => Current.Name.Split('\\').Last().ToLowerInvariant();
  public string SecurityIdentifier => Current.User?.Value ?? throw new BwsException(BwsFailureKind.TokenIdentityMismatch, "The current Windows identity has no SID.");
  private static WindowsIdentity Current
  {
    get
    {
      if (!OperatingSystem.IsWindows()) throw new BwsException(BwsFailureKind.UnsupportedPlatform, "The DPAPI token source requires Windows.");
      return WindowsIdentity.GetCurrent();
    }
  }
}