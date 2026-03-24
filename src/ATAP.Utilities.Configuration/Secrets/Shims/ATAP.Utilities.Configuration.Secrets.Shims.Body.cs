using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.Configuration.Secrets.Shims;

/// <summary>
/// Routes secret lookups across all registered <see cref="IConfigurationSecretsShim"/> providers.
/// Returns the first non-null value found, in registration order.
/// Register via DI as <see cref="ATAP.Utilities.Configuration.Secrets.IConfigurationSecrets"/>.
/// </summary>
public sealed class ConfigurationSecretsShims : ATAP.Utilities.Configuration.Secrets.IConfigurationSecrets
{
    private readonly IReadOnlyList<IConfigurationSecretsShim> _shims;

    public ConfigurationSecretsShims(IEnumerable<IConfigurationSecretsShim> shims)
        => _shims = new List<IConfigurationSecretsShim>(
            shims ?? throw new ArgumentNullException(nameof(shims)));

    /// <summary>Returns the first non-null value of <paramref name="fieldName"/> across all registered shims.</summary>
    public async Task<string?> GetSecretAsync(string secretName, string fieldName = "password", CancellationToken cancellationToken = default)
    {
        foreach (var shim in _shims)
        {
            var value = await shim.GetSecretAsync(secretName, fieldName, cancellationToken).ConfigureAwait(false);
            if (value is not null)
                return value;
        }
        return null;
    }

    /// <summary>Returns <c>true</c> if any registered shim contains <paramref name="secretName"/>.</summary>
    public async Task<bool> SecretExistsAsync(string secretName, CancellationToken cancellationToken = default)
    {
        foreach (var shim in _shims)
        {
            if (await shim.SecretExistsAsync(secretName, cancellationToken).ConfigureAwait(false))
                return true;
        }
        return false;
    }
}
