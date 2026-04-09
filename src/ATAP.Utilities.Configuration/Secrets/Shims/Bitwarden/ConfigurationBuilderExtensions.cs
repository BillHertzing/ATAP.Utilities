using System;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden;

/// <summary>
/// Extension methods for wiring Bitwarden secrets into the .NET configuration pipeline.
/// </summary>
public static class ConfigurationBuilderExtensions
{
    /// <summary>
    /// Adds a <see cref="BitwardenConfigurationSource"/> to <paramref name="builder"/> so that
    /// each mapping's config key is populated from the Bitwarden vault when the host builds
    /// its <c>IConfiguration</c>.
    /// </summary>
    /// <param name="builder">The configuration builder to extend.</param>
    /// <param name="mappings">
    /// A collection of <see cref="BitwardenSecretMapping"/> objects, each pairing a
    /// .NET config key with a Bitwarden item name and field.
    /// </param>
    /// <returns>The same <paramref name="builder"/> for chaining.</returns>
    public static IConfigurationBuilder AddBitwardenSecrets(
        this IConfigurationBuilder builder,
        IEnumerable<BitwardenSecretMapping> mappings)
        => builder.Add(new BitwardenConfigurationSource(mappings, new BitwardenSecretsShim()));

    /// <summary>
    /// Adds secrets from the Bitwarden vault using <see cref="ATAP.Utilities.Secrets.SecretMapping"/>
    /// directly via the ATAP.Utilities.Secrets configuration source. This overload allows consumers
    /// to share a single mapping type across the Configuration and Secrets layers.
    /// </summary>
    /// <param name="builder">The configuration builder to extend.</param>
    /// <param name="mappings">
    /// A collection of <see cref="ATAP.Utilities.Secrets.SecretMapping"/> objects from the
    /// ATAP.Utilities.Secrets package.
    /// </param>
    /// <param name="configure">Optional callback to override default Bitwarden options.</param>
    /// <returns>The same <paramref name="builder"/> for chaining.</returns>
    public static IConfigurationBuilder AddBitwardenSecrets(
        this IConfigurationBuilder builder,
        IEnumerable<ATAP.Utilities.Secrets.SecretMapping> mappings,
        Action<ATAP.Utilities.Secrets.BitwardenSecretsOptions>? configure = null)
    {
        var options = new ATAP.Utilities.Secrets.BitwardenSecretsOptions();
        configure?.Invoke(options);
        return builder.Add(
            new ATAP.Utilities.Secrets.BitwardenConfigurationSource(options, mappings));
    }
}
