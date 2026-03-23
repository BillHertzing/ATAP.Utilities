using ATAP.Utilities.Configuration.Secrets.Providers;

namespace ATAP.Utilities.Configuration.Secrets;

/// <summary>
/// Fluent builder for registering secret providers on a
/// <see cref="SecretProvidersConfigurationSource"/>.
/// </summary>
public sealed class SecretProvidersBuilder
{
  private readonly SecretProvidersConfigurationSource _source = new();

  /// <summary>
  /// Registers the Bitwarden Password Manager provider.
  /// Retrieves secrets via the <c>bw</c> CLI using a session token stored in
  /// the <c>BW_SESSION</c> environment variable (configurable via options).
  /// </summary>
  /// <param name="mappings">Secrets to fetch and the configuration keys to populate.</param>
  /// <param name="configure">Optional callback to override default options.</param>
  public SecretProvidersBuilder AddBitwardenPasswordManager(
    IReadOnlyList<SecretMapping> mappings,
    Action<BitwardenPasswordManagerOptions>? configure = null)
  {
    var opts = new BitwardenPasswordManagerOptions();
    configure?.Invoke(opts);
    _source.Registrations.Add((new BitwardenPasswordManagerProvider(opts), mappings));
    return this;
  }

  /// <summary>
  /// Registers the Bitwarden Secrets Manager provider stub.
  /// This provider is not yet implemented and will throw
  /// <see cref="NotImplementedException"/> when queried.
  /// Register it only after completing the implementation.
  /// </summary>
  /// <param name="mappings">Secrets to fetch and the configuration keys to populate.</param>
  /// <param name="configure">Optional callback to override default options.</param>
  public SecretProvidersBuilder AddBitwardenSecretsManager(
    IReadOnlyList<SecretMapping> mappings,
    Action<BitwardenSecretsManagerOptions>? configure = null)
  {
    var opts = new BitwardenSecretsManagerOptions();
    configure?.Invoke(opts);
    _source.Registrations.Add((new BitwardenSecretsManagerProvider(opts), mappings));
    return this;
  }

  internal SecretProvidersConfigurationSource Build() => _source;
}
