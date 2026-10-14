using System.Diagnostics;
using System.Security.Cryptography;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

internal sealed class BwsAccessTokenLease : IBwsAccessTokenLease
{
  private char[]? _token;
  public BwsAccessTokenLease(char[] token) { _token = token; }
  public void ApplyTo(ProcessStartInfo startInfo)
  {
    ArgumentNullException.ThrowIfNull(startInfo);
    var token = _token ?? throw new ObjectDisposedException(nameof(BwsAccessTokenLease));
    if (startInfo.UseShellExecute) throw new BwsException(BwsFailureKind.InvalidConfiguration, "The token can only be applied to a direct child process.");
    startInfo.Environment["BWS_ACCESS_TOKEN"] = new string(token);
  }
  public void Dispose()
  {
    var token = Interlocked.Exchange(ref _token, null);
    if (token is not null) Array.Clear(token);
  }
}