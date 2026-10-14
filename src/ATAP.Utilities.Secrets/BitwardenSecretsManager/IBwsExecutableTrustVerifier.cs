using System.Security.Cryptography;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public interface IBwsExecutableTrustVerifier
{
  void Verify(string executablePath);
}

public sealed class BwsExecutableTrustVerifier : IBwsExecutableTrustVerifier
{
  private readonly BitwardenSecretsManagerOptions _options;
  public BwsExecutableTrustVerifier(BitwardenSecretsManagerOptions options) => _options = options;

  public void Verify(string executablePath)
  {
    if (!Path.IsPathFullyQualified(executablePath) || executablePath.StartsWith(@"\\", StringComparison.Ordinal))
      throw new BwsException(BwsFailureKind.CliUntrusted, "The bws executable must be an absolute local path.");
    var info = new FileInfo(executablePath);
    if (!info.Exists) throw new BwsException(BwsFailureKind.CliNotFound, "The configured bws executable was not found.");
    if ((info.Attributes & (FileAttributes.ReparsePoint | FileAttributes.Directory)) != 0)
      throw new BwsException(BwsFailureKind.CliUntrusted, "The configured bws executable is not a trusted regular file.");
    if (_options.TrustedBwsSha256.Length != 64 || !_options.TrustedBwsSha256.All(Uri.IsHexDigit))
      throw new BwsException(BwsFailureKind.CliUntrusted, "A 64-character trusted bws SHA-256 digest must be configured.");
    using var stream = new FileStream(executablePath, FileMode.Open, FileAccess.Read, FileShare.Read);
    var actual = SHA256.HashData(stream);
    var expected = Convert.FromHexString(_options.TrustedBwsSha256);
    try { if (!CryptographicOperations.FixedTimeEquals(actual, expected)) throw new BwsException(BwsFailureKind.CliUntrusted, "The configured bws executable does not match its trusted SHA-256 digest."); }
    finally { CryptographicOperations.ZeroMemory(actual); CryptographicOperations.ZeroMemory(expected); }
  }
}