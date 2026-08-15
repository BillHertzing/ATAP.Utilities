using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public static class ConfigurationBuilderExtensions
{
  public static async Task<IConfigurationBuilder> AddBitwardenSecretsManagerConfigurationAsync(
    this IConfigurationBuilder builder,
    BitwardenSecretsManagerConfigurationLoader loader,
    IEnumerable<BwsSecretMapping> mappings,
    CancellationToken cancellationToken = default)
  {
    ArgumentNullException.ThrowIfNull(builder);
    ArgumentNullException.ThrowIfNull(loader);
    var values = await loader.LoadAsync(mappings, cancellationToken).ConfigureAwait(false);
    builder.AddInMemoryCollection(values);
    return builder;
  }
}