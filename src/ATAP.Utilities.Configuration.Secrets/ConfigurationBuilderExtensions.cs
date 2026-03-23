using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Configuration.Secrets;

/// <summary>
/// Extension methods for <see cref="IConfigurationBuilder"/> to add secret providers.
/// </summary>
public static class ConfigurationBuilderExtensions
{
  /// <summary>
  /// Adds one or more secret providers as a configuration source.
  /// Call this after all other sources so that secrets override file and
  /// environment-variable values.
  /// </summary>
  /// <param name="builder">The configuration builder to extend.</param>
  /// <param name="configure">
  /// Action that registers providers and their secret-to-key mappings via
  /// <see cref="SecretProvidersBuilder"/>.
  /// </param>
  /// <returns>The same <paramref name="builder"/> for chaining.</returns>
  public static IConfigurationBuilder AddSecretProviders(
    this IConfigurationBuilder builder,
    Action<SecretProvidersBuilder> configure)
  {
    var spBuilder = new SecretProvidersBuilder();
    configure(spBuilder);
    builder.Add(spBuilder.Build());
    return builder;
  }
}
