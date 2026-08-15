namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public interface IWindowsIdentityContext
{
  string MachineName { get; }
  string SamAccountName { get; }
  string SecurityIdentifier { get; }
  string ProgramDataDirectory { get; }
}