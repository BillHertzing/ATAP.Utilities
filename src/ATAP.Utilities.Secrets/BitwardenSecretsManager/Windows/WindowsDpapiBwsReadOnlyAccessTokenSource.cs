namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public sealed class WindowsDpapiBwsReadOnlyAccessTokenSource : IBwsReadOnlyAccessTokenSource
{
  private readonly WindowsBwsTokenSourceOptions _options;
  private readonly IWindowsIdentityContext _identity;
  private readonly BwsDpapiEnvelopeReader _envelopeReader;
  private readonly PowerShellCredentialCliXmlReader _legacyReader;
  private readonly IWindowsTokenPathSecurityValidator _pathSecurityValidator;

  public WindowsDpapiBwsReadOnlyAccessTokenSource(WindowsBwsTokenSourceOptions options, IWindowsIdentityContext identity, BwsDpapiEnvelopeReader envelopeReader, PowerShellCredentialCliXmlReader legacyReader, IWindowsTokenPathSecurityValidator pathSecurityValidator)
  { _options = options; _identity = identity; _envelopeReader = envelopeReader; _legacyReader = legacyReader; _pathSecurityValidator = pathSecurityValidator; }

  public ValueTask<IBwsAccessTokenLease> AcquireAsync(CancellationToken cancellationToken = default)
  {
    cancellationToken.ThrowIfCancellationRequested();
    if (!OperatingSystem.IsWindows()) throw new BwsException(BwsFailureKind.UnsupportedPlatform, "The DPAPI token source requires Windows.");
    foreach (var value in new[] { _identity.MachineName, _identity.SamAccountName, _options.ApplicationId, _options.VaultGroupingId, _options.LegacyTokenLabel }) ValidateSegment(value);
    if (_options.MaximumCredentialFileBytes is < 1 or > 16 * 1024 * 1024)
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "The token-file size limit is outside the supported range.");
    var host = _identity.MachineName.ToUpperInvariant();
    var sam = _identity.SamAccountName.ToLowerInvariant();
    var enabledSlots = ValidateAndGetEnabledSlots();
    var root = Path.GetFullPath(_options.CredentialRootDirectory ?? Path.Combine(_identity.ProgramDataDirectory, "ATAP", "BitwardenCredentials"));
    var directory = Path.GetFullPath(Path.Combine(root, sam));
    EnsureContained(root, directory);
    var candidates = enabledSlots.Select(slot =>
    {
      var path = Path.GetFullPath(Path.Combine(directory, RenderFilename(slot.FilenamePattern, host, sam)));
      EnsureContained(directory, path);
      return new TokenCandidate(slot, path);
    }).ToArray();
    if (candidates.Select(candidate => candidate.Path).Distinct(StringComparer.OrdinalIgnoreCase).Count() != candidates.Length)
      throw new BwsException(BwsFailureKind.TokenCandidateAmbiguous, "Enabled BWS token slots resolve to duplicate candidate paths.");
    if (!Directory.Exists(directory) || (File.GetAttributes(directory) & FileAttributes.ReparsePoint) != 0)
      throw new BwsException(BwsFailureKind.TokenFolderMissing, "The identity-specific token directory is missing or unsafe.");
    candidates = candidates.Where(candidate => File.Exists(candidate.Path)).ToArray();
    if (candidates.Length == 0) throw new BwsException(BwsFailureKind.TokenFileMissing, "No enabled identity-bound BWS token file was found.");
    if (candidates.Length != 1) throw new BwsException(BwsFailureKind.TokenCandidateAmbiguous, "More than one enabled BWS token file exists.");
    var candidate = candidates[0];
    _pathSecurityValidator.Validate(directory, candidate.Path, _identity.SecurityIdentifier);
    var binding = new BwsTokenBinding(host, _identity.SecurityIdentifier, sam, _options.ApplicationId, _options.VaultGroupingId);
    var token = candidate.Slot.PhysicalFormat switch
    {
      WindowsBwsTokenPhysicalFormat.AtapBwsDpapiEnvelopeV1 =>
        _envelopeReader.ReadToken(candidate.Path, binding, _options.MaximumCredentialFileBytes),
      WindowsBwsTokenPhysicalFormat.PowerShellCredentialCliXml when _options.AllowLegacyPowerShellCliXml =>
        _legacyReader.ReadToken(candidate.Path, "BWS_ACCESS_TOKEN", _options.MaximumCredentialFileBytes),
      WindowsBwsTokenPhysicalFormat.PowerShellCredentialCliXml =>
        throw new BwsException(BwsFailureKind.TokenFormatUnsupported, "Legacy PowerShell CLIXML token files are disabled."),
      _ => throw new BwsException(BwsFailureKind.InvalidConfiguration, "The enabled BWS token slot declares an unsupported physical format."),
    };
    return ValueTask.FromResult<IBwsAccessTokenLease>(new BwsAccessTokenLease(token));
  }

  private WindowsBwsTokenSlotDescriptor[] ValidateAndGetEnabledSlots()
  {
    if (!string.IsNullOrWhiteSpace(_options.EnabledSlotId))
      return [_options.ResolveConfiguredSlot()];
    if (_options.TokenSlots is null || _options.TokenSlots.Count == 0)
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "At least one BWS token-slot descriptor is required.");

    var slotIds = new HashSet<string>(StringComparer.Ordinal);
    foreach (var slot in _options.TokenSlots)
    {
      if (slot is null || string.IsNullOrWhiteSpace(slot.SlotId) || !slotIds.Add(slot.SlotId) ||
          string.IsNullOrWhiteSpace(slot.FilenamePattern) ||
          slot.Purpose != BwsTokenPurpose.ReadOnly ||
          !Enum.IsDefined(slot.PhysicalFormat) ||
          slot.RequiredBindingFields is null || slot.RequiredBindingFields.Count == 0 ||
          slot.RequiredBindingFields.Any(string.IsNullOrWhiteSpace) ||
          slot.RequiredBindingFields.Distinct(StringComparer.Ordinal).Count() != slot.RequiredBindingFields.Count)
        throw new BwsException(BwsFailureKind.InvalidConfiguration, "A BWS token-slot descriptor is invalid or is not ReadOnly.");
    }

    var enabledSlots = _options.TokenSlots.Where(slot => slot.Enabled).ToArray();
    if (enabledSlots.Length == 0)
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "At least one BWS token slot must be enabled.");
    return enabledSlots;
  }

  private string RenderFilename(string pattern, string host, string sam)
  {
    var filename = pattern
      .Replace("{HostUpper}", host, StringComparison.Ordinal)
      .Replace("{SamLower}", sam, StringComparison.Ordinal)
      .Replace("{ApplicationId}", _options.ApplicationId, StringComparison.Ordinal)
      .Replace("{LegacyTokenLabel}", _options.LegacyTokenLabel, StringComparison.Ordinal);
    if (filename.Contains('{') || filename.Contains('}')) throw new BwsException(BwsFailureKind.InvalidConfiguration, "A BWS token-slot filename pattern contains an unsupported variable.");
    ValidateSegment(filename);
    return filename;
  }

  private sealed record TokenCandidate(WindowsBwsTokenSlotDescriptor Slot, string Path);

  private static void ValidateSegment(string value)
  {
    if (string.IsNullOrWhiteSpace(value) || value is "." or ".." || value.EndsWith('.') || value.EndsWith(' ') ||
        value.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "A token path segment is invalid.");
  }
  private static void EnsureContained(string root, string path)
  { var prefix = root.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar; if (!path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) throw new BwsException(BwsFailureKind.TokenPathInaccessible, "The token path escapes its configured root."); }
}
