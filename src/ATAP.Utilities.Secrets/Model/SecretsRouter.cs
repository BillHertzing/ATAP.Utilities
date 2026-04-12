using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.Secrets;

public class SecretsRouter : SecretsAbstract
{
  private readonly IReadOnlyList<ISecretsAbstract> _providers;

  public SecretsRouter(IEnumerable<ISecretsAbstract> providers)
  {
    _providers = providers.ToList();
  }

  public override string ProviderName => "Router";

  public override bool IsAvailable() => _providers.Any(p => p.IsAvailable());

  public override async Task<string?> GetSecretAsync(
      string secretName,
      string? fieldName = null,
      CancellationToken cancellationToken = default)
  {
    foreach (var provider in _providers)
    {
      if (!provider.IsAvailable())
        continue;
      var value = await provider.GetSecretAsync(secretName, fieldName, cancellationToken);
      if (value is not null)
        return value;
    }
    return null;
  }

  public override async Task<bool> SecretExistsAsync(
      string secretName,
      CancellationToken cancellationToken = default)
  {
    foreach (var provider in _providers)
    {
      if (!provider.IsAvailable())
        continue;
      if (await provider.SecretExistsAsync(secretName, cancellationToken))
        return true;
    }
    return false;
  }
}
