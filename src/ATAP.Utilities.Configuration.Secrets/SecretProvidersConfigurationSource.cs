using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Configuration.Secrets;

/// <summary>
/// <see cref="IConfigurationSource"/> that loads secrets from one or more
/// <see cref="ISecretProvider"/> instances into IConfiguration.
/// </summary>
public sealed class SecretProvidersConfigurationSource : IConfigurationSource
{
  /// <summary>
  /// Ordered list of (provider, mappings) pairs.
  /// When multiple providers supply the same configuration key, the last registration wins.
  /// </summary>
  public List<(ISecretProvider Provider, IReadOnlyList<SecretMapping> Mappings)> Registrations { get; } = [];

  /// <inheritdoc />
  public IConfigurationProvider Build(IConfigurationBuilder builder) =>
    new SecretProvidersConfigurationProvider(this);
}
