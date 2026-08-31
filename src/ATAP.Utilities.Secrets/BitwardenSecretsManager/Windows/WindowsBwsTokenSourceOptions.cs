namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public sealed class WindowsBwsTokenSourceOptions
{
  public const string DefaultConfigurationSectionName = "BitwardenSecretsManager:WindowsTokenSource";

  public string? CredentialRootDirectory { get; set; }
  public string ApplicationId { get; set; } = string.Empty;
  public string VaultGroupingId { get; set; } = string.Empty;
  public string? EnabledSlotId { get; set; }
  public string LegacyTokenLabel { get; set; } = "CommonCIForBitwardenReadOnly";
  public bool AllowLegacyPowerShellCliXml { get; set; }
  public int MaximumCredentialFileBytes { get; set; } = 1024 * 1024;
  public IList<WindowsBwsTokenSlotDescriptor> TokenSlots { get; set; } =
  [
    WindowsBwsTokenSlotDescriptor.LegacyCiCliXml,
    WindowsBwsTokenSlotDescriptor.LegacyUnlabelledCliXml,
    WindowsBwsTokenSlotDescriptor.ApplicationEnvelope with { Enabled = true },
  ];

  public WindowsBwsTokenSlotDescriptor ResolveConfiguredSlot()
  {
    if (string.IsNullOrWhiteSpace(EnabledSlotId) ||
        !WindowsBwsTokenSlotProfile.Registered.TryGetValue(EnabledSlotId, out var profile))
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "The configured BWS token slot is unknown or unregistered.");

    if ((!string.IsNullOrEmpty(ApplicationId) && !string.Equals(ApplicationId, profile.ApplicationId, StringComparison.Ordinal)) ||
        (!string.IsNullOrEmpty(VaultGroupingId) && !string.Equals(VaultGroupingId, profile.VaultGroupingId, StringComparison.Ordinal)))
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "The configured BWS token slot binding is invalid.");

    ApplicationId = profile.ApplicationId;
    VaultGroupingId = profile.VaultGroupingId;
    return profile.Descriptor with { Enabled = true };
  }

  public void ValidateStartupConfiguration()
  {
    if (!string.IsNullOrWhiteSpace(EnabledSlotId)) _ = ResolveConfiguredSlot();
  }
}

public sealed class WindowsBwsTokenSourceConfiguration
{
  public string? CredentialRootDirectory { get; set; }
  public string? EnabledSlotId { get; set; }
  public string? LegacyTokenLabel { get; set; }
  public bool AllowLegacyPowerShellCliXml { get; set; }
  public int MaximumCredentialFileBytes { get; set; } = 1024 * 1024;

  public WindowsBwsTokenSourceOptions ToOptions() => new()
  {
    CredentialRootDirectory = CredentialRootDirectory,
    EnabledSlotId = EnabledSlotId,
    LegacyTokenLabel = LegacyTokenLabel ?? "CommonCIForBitwardenReadOnly",
    AllowLegacyPowerShellCliXml = AllowLegacyPowerShellCliXml,
    MaximumCredentialFileBytes = MaximumCredentialFileBytes,
  };
}

public sealed record WindowsBwsTokenSlotProfile(
  string SlotId,
  WindowsBwsTokenSlotDescriptor Descriptor,
  string ApplicationId,
  string VaultGroupingId)
{
  public static IReadOnlyDictionary<string, WindowsBwsTokenSlotProfile> Registered { get; } =
    new Dictionary<string, WindowsBwsTokenSlotProfile>(StringComparer.Ordinal)
    {
      ["aceoutpost-application"] = new("aceoutpost-application", WindowsBwsTokenSlotDescriptor.ApplicationEnvelope, "AceOutpost", "Ace"),
      ["aceoutpost-developer"] = new("aceoutpost-developer", WindowsBwsTokenSlotDescriptor.ApplicationEnvelope, "AceOutpost", "Ace"),
      ["acecommander-application"] = new("acecommander-application", WindowsBwsTokenSlotDescriptor.ApplicationEnvelope, "AceCommander", "Ace"),
      ["acecommander-developer"] = new("acecommander-developer", WindowsBwsTokenSlotDescriptor.ApplicationEnvelope, "AceCommander", "Ace"),
    };
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
