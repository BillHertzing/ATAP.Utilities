using System.Threading;
using System.Threading.Tasks;
using ATAP.Utilities.Configuration.Secrets.Shims;

namespace ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden;

/// <summary>
/// Adapter that implements <see cref="IConfigurationSecretsShim"/> by delegating
/// to <see cref="ATAP.Utilities.Secrets.BitwardenSecretsShim"/> — the single
/// canonical Bitwarden CLI implementation in the ATAP.Utilities.Secrets package.
/// </summary>
public sealed class BitwardenSecretsShim : IConfigurationSecretsShim
{
    private readonly ATAP.Utilities.Secrets.BitwardenSecretsShim _inner;

    /// <summary>Creates a new adapter with default Bitwarden options.</summary>
    public BitwardenSecretsShim()
        => _inner = new ATAP.Utilities.Secrets.BitwardenSecretsShim();

    /// <summary>Creates a new adapter with the specified Bitwarden options.</summary>
    public BitwardenSecretsShim(ATAP.Utilities.Secrets.BitwardenSecretsOptions options)
        => _inner = new ATAP.Utilities.Secrets.BitwardenSecretsShim(options);

    /// <inheritdoc/>
    public string ProviderName => _inner.ProviderName;

    /// <inheritdoc/>
    public Task<string?> GetSecretAsync(
        string secretName,
        string fieldName = "password",
        CancellationToken cancellationToken = default)
        => _inner.GetSecretAsync(secretName, fieldName, cancellationToken);

    /// <inheritdoc/>
    public Task<bool> SecretExistsAsync(
        string secretName,
        CancellationToken cancellationToken = default)
        => _inner.SecretExistsAsync(secretName, cancellationToken);
}
