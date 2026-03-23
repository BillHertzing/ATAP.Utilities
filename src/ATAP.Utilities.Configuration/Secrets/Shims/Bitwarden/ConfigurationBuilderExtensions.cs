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
    /// <remarks>
    /// This source is added after the env-var providers, so an environment variable with
    /// the same key will override the vault value — preserving the standard configuration
    /// override hierarchy.
    /// <para>
    /// Requires <c>BW_SESSION</c> to be set in the process environment before host startup
    /// (populated at login by <c>Initialize-BitwardenSession</c> in LoginScript.ps1).
    /// </para>
    /// </remarks>
    public static IConfigurationBuilder AddBitwardenSecrets(
        this IConfigurationBuilder builder,
        IEnumerable<BitwardenSecretMapping> mappings)
        => builder.Add(new BitwardenConfigurationSource(mappings, new BitwardenSecretsShim()));
}
