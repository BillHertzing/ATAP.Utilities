using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.Secrets;

public abstract class SecretsAbstract : ISecretsAbstract
{
  public ISecretsOptionsAbstract Options { get; set; } = new SecretsOptions(new object());
  public abstract string ProviderName { get; }
  public abstract bool IsAvailable();
  public abstract Task<string?> GetSecretAsync(string secretName, string? fieldName = null, CancellationToken cancellationToken = default);
  public abstract Task<bool> SecretExistsAsync(string secretName, CancellationToken cancellationToken = default);
}
