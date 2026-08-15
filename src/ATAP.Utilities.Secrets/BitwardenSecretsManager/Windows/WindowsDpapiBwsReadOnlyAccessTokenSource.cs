using System.Xml;

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
    var root = Path.GetFullPath(_options.CredentialRootDirectory ?? Path.Combine(_identity.ProgramDataDirectory, "ATAP", "BitwardenCredentials"));
    var directory = Path.GetFullPath(Path.Combine(root, sam)); EnsureContained(root, directory);
    if (!Directory.Exists(directory) || (File.GetAttributes(directory) & FileAttributes.ReparsePoint) != 0)
      throw new BwsException(BwsFailureKind.TokenFolderMissing, "The identity-specific token directory is missing or unsafe.");
    var candidates = new[] {
      Path.Combine(directory, $"{host}_{sam}_BWS_{_options.ApplicationId}_ReadOnly_AccessToken.xml"),
      Path.Combine(directory, $"{host}_{sam}_BWS_{_options.LegacyTokenLabel}_AccessToken.xml"),
      Path.Combine(directory, $"{host}_{sam}_BWS_AccessToken.xml") };
    foreach (var candidate in candidates) EnsureContained(directory, Path.GetFullPath(candidate));
    candidates = candidates.Where(File.Exists).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
    if (candidates.Length == 0) throw new BwsException(BwsFailureKind.TokenFileMissing, "No recognized identity-bound BWS token file was found.");
    if (candidates.Length != 1) throw new BwsException(BwsFailureKind.TokenCandidateAmbiguous, "More than one recognized BWS token file exists.");
    _pathSecurityValidator.Validate(directory, candidates[0], _identity.SecurityIdentifier);
    var binding = new BwsTokenBinding(host, _identity.SecurityIdentifier, sam, _options.ApplicationId, _options.VaultGroupingId);
    var token = HasEnvelopeRoot(candidates[0])
      ? _envelopeReader.ReadToken(candidates[0], binding, _options.MaximumCredentialFileBytes)
      : _options.AllowLegacyPowerShellCliXml
        ? _legacyReader.ReadToken(candidates[0], "BWS_ACCESS_TOKEN", _options.MaximumCredentialFileBytes)
        : throw new BwsException(BwsFailureKind.TokenFormatUnsupported, "Legacy PowerShell CLIXML token files are disabled.");
    return ValueTask.FromResult<IBwsAccessTokenLease>(new BwsAccessTokenLease(token));
  }

  private static bool HasEnvelopeRoot(string path)
  {
    using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
    using var reader = XmlReader.Create(stream, new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null });
    reader.MoveToContent(); return reader.LocalName == BwsDpapiEnvelopeReader.RootName;
  }
  private static void ValidateSegment(string value)
  {
    if (string.IsNullOrWhiteSpace(value) || value is "." or ".." || value.EndsWith('.') || value.EndsWith(' ') ||
        value.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "A token path segment is invalid.");
  }
  private static void EnsureContained(string root, string path)
  { var prefix = root.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar; if (!path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) throw new BwsException(BwsFailureKind.TokenPathInaccessible, "The token path escapes its configured root."); }
}