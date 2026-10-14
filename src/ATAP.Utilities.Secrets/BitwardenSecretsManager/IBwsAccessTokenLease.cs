using System.Diagnostics;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public interface IBwsAccessTokenLease : IDisposable
{
  void ApplyTo(ProcessStartInfo startInfo);
}
