namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public sealed class WindowsBwsTokenSourceOptions
{
  public string? CredentialRootDirectory { get; set; }
  public string ApplicationId { get; set; } = string.Empty;
  public string VaultGroupingId { get; set; } = string.Empty;
  public string LegacyTokenLabel { get; set; } = "CommonCIForBitwardenReadOnly";
  public bool AllowLegacyPowerShellCliXml { get; set; }
  public int MaximumCredentialFileBytes { get; set; } = 1024 * 1024;
}