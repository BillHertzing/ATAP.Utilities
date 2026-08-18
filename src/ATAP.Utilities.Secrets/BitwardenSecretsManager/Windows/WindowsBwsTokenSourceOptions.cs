namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public sealed class WindowsBwsTokenSourceOptions
{
  public string? CredentialRootDirectory { get; set; }
  public string ApplicationId { get; set; } = string.Empty;
  public string VaultGroupingId { get; set; } = string.Empty;
  public string LegacyTokenLabel { get; set; } = "CommonCIForBitwardenReadOnly";
  public bool AllowLegacyPowerShellCliXml { get; set; }
  public int MaximumCredentialFileBytes { get; set; } = 1024 * 1024;
  public IList<WindowsBwsTokenSlotDescriptor> TokenSlots { get; set; } =
  [
    WindowsBwsTokenSlotDescriptor.LegacyCiCliXml,
    WindowsBwsTokenSlotDescriptor.LegacyUnlabelledCliXml,
    WindowsBwsTokenSlotDescriptor.ApplicationEnvelope with { Enabled = true },
  ];
}

public enum WindowsBwsTokenPhysicalFormat
{
  PowerShellCredentialCliXml,
  AtapBwsDpapiEnvelopeV1,
}

public sealed record WindowsBwsTokenSlotDescriptor(
  string SlotId,
  string FilenamePattern,
  WindowsBwsTokenPhysicalFormat PhysicalFormat,
  BwsTokenPurpose Purpose,
  IReadOnlyList<string> RequiredBindingFields,
  bool Enabled = false)
{
  public static WindowsBwsTokenSlotDescriptor LegacyCiCliXml { get; } = new(
    "legacy-ci-clixml",
    "{HostUpper}_{SamLower}_BWS_{LegacyTokenLabel}_AccessToken.xml",
    WindowsBwsTokenPhysicalFormat.PowerShellCredentialCliXml,
    BwsTokenPurpose.ReadOnly,
    ["CurrentUserDpapi", "HostUpper", "SamLower", "BWS_ACCESS_TOKEN"]);

  public static WindowsBwsTokenSlotDescriptor LegacyUnlabelledCliXml { get; } = new(
    "legacy-unlabelled-clixml",
    "{HostUpper}_{SamLower}_BWS_AccessToken.xml",
    WindowsBwsTokenPhysicalFormat.PowerShellCredentialCliXml,
    BwsTokenPurpose.ReadOnly,
    ["CurrentUserDpapi", "HostUpper", "SamLower", "BWS_ACCESS_TOKEN"]);

  public static WindowsBwsTokenSlotDescriptor ApplicationEnvelope { get; } = new(
    "application-envelope",
    "{HostUpper}_{SamLower}_BWS_{ApplicationId}_ReadOnly_AccessToken.xml",
    WindowsBwsTokenPhysicalFormat.AtapBwsDpapiEnvelopeV1,
    BwsTokenPurpose.ReadOnly,
    ["Host", "Sid", "SamAccountName", "ApplicationId", "VaultGroupingId", "Provider", "EnvelopeVersion", "ReadOnly", "CurrentUserDpapi"]);
}
