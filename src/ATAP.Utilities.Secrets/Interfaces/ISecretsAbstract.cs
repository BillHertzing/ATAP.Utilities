using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.Secrets;

public interface ISecretsAbstract
{
  ISecretsOptionsAbstract Options { get; set; }
  string ProviderName { get; }
  bool IsAvailable();
  Task<string?> GetSecretAsync(string secretName, string? fieldName = null, CancellationToken cancellationToken = default);
  Task<bool> SecretExistsAsync(string secretName, CancellationToken cancellationToken = default);
}
