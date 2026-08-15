namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public sealed class BitwardenSecretsManagerConfigurationLoader
{
  private readonly BitwardenSecretsManagerProvider _provider;
  public BitwardenSecretsManagerConfigurationLoader(BitwardenSecretsManagerProvider provider) => _provider = provider;
  public Task<IReadOnlyDictionary<string, string?>> LoadAsync(IEnumerable<BwsSecretMapping> mappings, CancellationToken cancellationToken = default) =>
    _provider.GetMappedSecretsAsync(mappings, cancellationToken);
}