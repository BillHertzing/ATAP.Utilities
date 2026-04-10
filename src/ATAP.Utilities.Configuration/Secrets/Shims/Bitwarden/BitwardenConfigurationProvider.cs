using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using ATAP.Utilities.Configuration.Secrets.Shims;

namespace ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden;

/// <summary>
/// <see cref="IConfigurationSource"/> that loads secrets from the Bitwarden vault into the
/// .NET configuration pipeline at startup.  Wire it in via
/// <see cref="ConfigurationBuilderExtensions.AddBitwardenSecrets"/>.
/// </summary>
[Obsolete("Use ATAP.Utilities.Secrets.BitwardenConfigurationSource instead. This type will be removed in a future release.")]
public sealed class BitwardenConfigurationSource : IConfigurationSource
{
    private readonly IEnumerable<BitwardenSecretMapping> _mappings;
    private readonly IConfigurationSecretsShim _shim;

    /// <param name="mappings">The set of config-key → vault-item/field mappings to load.</param>
    /// <param name="shim">The secrets back-end used to fetch values (injectable for testing).</param>
    public BitwardenConfigurationSource(
        IEnumerable<BitwardenSecretMapping> mappings,
        IConfigurationSecretsShim shim)
    {
        _mappings = mappings;
        _shim = shim;
    }

    /// <inheritdoc/>
    public IConfigurationProvider Build(IConfigurationBuilder builder)
        => new BitwardenConfigurationProvider(_mappings, _shim);
}

/// <summary>
/// Loads each <see cref="BitwardenSecretMapping"/> from the Bitwarden vault and populates
/// the <see cref="Microsoft.Extensions.Configuration.ConfigurationProvider.Data"/> dictionary
/// so the values are available via <c>IConfiguration</c>.
/// </summary>
/// <remarks>
/// <see cref="Load"/> is synchronous (required by the configuration model) and blocks on
/// the async <see cref="IConfigurationSecretsShim.GetSecretAsync"/> call via
/// <c>Task.Run(...).GetAwaiter().GetResult()</c>.  This is safe at host startup because no
/// synchronisation context exists yet.
/// <para>
/// Mappings whose vault item or field is not found are silently skipped — they do not
/// populate a config key and do not throw.
/// </para>
/// </remarks>
[Obsolete("Use ATAP.Utilities.Secrets.BitwardenConfigurationProvider instead. This type will be removed in a future release.")]
public sealed class BitwardenConfigurationProvider : ConfigurationProvider
{
    private readonly IEnumerable<BitwardenSecretMapping> _mappings;
    private readonly IConfigurationSecretsShim _shim;

    /// <param name="mappings">The set of config-key → vault-item/field mappings to load.</param>
    /// <param name="shim">The secrets back-end used to fetch values.</param>
    public BitwardenConfigurationProvider(
        IEnumerable<BitwardenSecretMapping> mappings,
        IConfigurationSecretsShim shim)
    {
        _mappings = mappings;
        _shim = shim;
    }

    /// <inheritdoc/>
    /// <summary>
    /// Fetches every mapped secret from the vault and populates <see cref="ConfigurationProvider.Data"/>.
    /// Called once at host startup by the configuration system.
    /// </summary>
    public override void Load()
    {
        foreach (var mapping in _mappings)
        {
            var value = Task.Run(() => _shim.GetSecretAsync(mapping.BwItemName, mapping.BwFieldName))
                            .GetAwaiter().GetResult();
            if (value is not null)
                Data[mapping.ConfigKey] = value;
        }
    }
}
