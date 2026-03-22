using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.Configuration.Secrets.Shims;

/// <summary>
/// Plugin contract for secrets-provider shim implementations.
/// Implement this interface to plug a new secret back-end (e.g. Bitwarden, Azure Key Vault)
/// into the AceCommander configuration pipeline.
/// Register all implementations with DI as <see cref="IConfigurationSecretsShim"/> and
/// inject <see cref="IConfigurationSecrets"/> as the top-level consumer interface.
/// </summary>
public interface IConfigurationSecretsShim
{
    /// <summary>Unique provider name (e.g. "Bitwarden", "AzureKeyVault").</summary>
    string ProviderName { get; }

    /// <summary>
    /// Returns the value of <paramref name="fieldName"/> within the item named
    /// <paramref name="secretName"/>, or <c>null</c> if the item or field is not found.
    /// </summary>
    /// <param name="secretName">The vault item name.</param>
    /// <param name="fieldName">
    /// The field to extract. <c>"password"</c> targets the built-in Password field;
    /// any other value targets a custom field by that name (case-insensitive).
    /// Defaults to <c>"password"</c>.
    /// </param>
    Task<string?> GetSecretAsync(string secretName, string fieldName = "password", CancellationToken cancellationToken = default);

    /// <summary>Returns <c>true</c> if <paramref name="secretName"/> exists in the provider.</summary>
    Task<bool> SecretExistsAsync(string secretName, CancellationToken cancellationToken = default);
}
