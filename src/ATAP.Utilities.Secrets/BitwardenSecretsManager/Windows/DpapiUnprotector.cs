using System.Security.Cryptography;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public sealed class DpapiUnprotector : IDpapiUnprotector, IBwsDpapiProtector
{
  public byte[] UnprotectForCurrentUser(byte[] ciphertext) => Unprotect(ciphertext, null);
  public byte[] UnprotectForCurrentUser(byte[] ciphertext, byte[] entropy) => Unprotect(ciphertext, entropy);

  private static byte[] Unprotect(byte[] ciphertext, byte[]? entropy)
  {
    if (!OperatingSystem.IsWindows()) throw new BwsException(BwsFailureKind.UnsupportedPlatform, "DPAPI CurrentUser is available only on Windows.");
    try { return ProtectedData.Unprotect(ciphertext, entropy, DataProtectionScope.CurrentUser); }
    catch (CryptographicException exception) { throw new BwsException(BwsFailureKind.TokenCiphertextCorrupt, "The DPAPI token could not be decrypted for the current identity.", exception); }
  }
}