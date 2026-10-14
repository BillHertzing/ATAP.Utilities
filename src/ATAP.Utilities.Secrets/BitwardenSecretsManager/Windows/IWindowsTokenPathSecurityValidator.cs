using System.Runtime.Versioning;
using System.Security.AccessControl;
using System.Security.Principal;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public interface IWindowsTokenPathSecurityValidator
{
  void Validate(string directoryPath, string tokenFilePath, string currentSid);
}

[SupportedOSPlatform("windows")]
public sealed class StrictWindowsTokenPathSecurityValidator : IWindowsTokenPathSecurityValidator
{
  public void Validate(string directoryPath, string tokenFilePath, string currentSid)
  {
    if (!OperatingSystem.IsWindows()) throw new BwsException(BwsFailureKind.UnsupportedPlatform, "Windows ACL validation requires Windows.");
    var identitySid = new SecurityIdentifier(currentSid);
    var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
      identitySid.Value,
      new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null).Value,
      new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null).Value };
    ValidateSecurity(new DirectoryInfo(directoryPath).GetAccessControl(AccessControlSections.Access | AccessControlSections.Owner), allowed, identitySid.Value, isDirectory: true);
    ValidateSecurity(new FileInfo(tokenFilePath).GetAccessControl(AccessControlSections.Access | AccessControlSections.Owner), allowed, identitySid.Value, isDirectory: false);
  }

  private static void ValidateSecurity(FileSystemSecurity security, HashSet<string> allowed, string identitySid, bool isDirectory)
  {
    if (!security.AreAccessRulesProtected) throw new BwsException(BwsFailureKind.TokenPathInaccessible, "The token path ACL must disable inheritance.");
    var owner = ((SecurityIdentifier?)security.GetOwner(typeof(SecurityIdentifier)))?.Value;
    if (owner is null || !allowed.Contains(owner)) throw new BwsException(BwsFailureKind.TokenPathInaccessible, "The token path owner is not an allowed identity.");
    var identityCanRead = false;
    foreach (FileSystemAccessRule rule in security.GetAccessRules(includeExplicit: true, includeInherited: true, typeof(SecurityIdentifier)))
    {
      var sid = ((SecurityIdentifier)rule.IdentityReference).Value;
      if (rule.IsInherited || !allowed.Contains(sid) || rule.AccessControlType != AccessControlType.Allow)
        throw new BwsException(BwsFailureKind.TokenPathInaccessible, "The token path ACL contains an inherited, denied, or unapproved access rule.");
      if (string.Equals(sid, identitySid, StringComparison.OrdinalIgnoreCase))
      {
        var required = isDirectory ? FileSystemRights.ListDirectory | FileSystemRights.ReadAttributes : FileSystemRights.ReadData | FileSystemRights.ReadAttributes;
        identityCanRead |= (rule.FileSystemRights & required) == required;
      }
    }
    if (!identityCanRead) throw new BwsException(BwsFailureKind.TokenPathInaccessible, "The current identity lacks explicit read access to the token path.");
  }
}