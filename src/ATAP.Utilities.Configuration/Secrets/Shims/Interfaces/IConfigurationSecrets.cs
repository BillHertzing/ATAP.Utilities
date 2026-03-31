using System.Threading;
using System.Threading.Tasks;

namespace ATAP.Utilities.Configuration.Secrets;

/// <summary>
/// Contract for retrieving secrets from a configured secrets provider.
/// Implementations are supplied by the plugin shim layer
/// (see ATAP.Utilities.Configuration.Secrets.Shims).
/// </summary>
public interface IConfigurationSecrets
{
    /// <summary>
    /// Returns the value of <paramref name="fieldName"/> within the item named
    /// <paramref name="secretName"/>, or <c>null</c> if the item or field is not found.
    /// </summary>
    /// <param name="secretName">The vault item name (e.g. "ProGet_Admin_API_Key").</param>
    /// <param name="fieldName">
    /// The field to extract. Use <c>"password"</c> for the built-in Password field.
    /// For custom fields use their exact vault name (e.g. <c>"token"</c>, <c>"key"</c>).
    /// Comparison is case-insensitive. Defaults to <c>"password"</c>.
    /// </param>
    Task<string?> GetSecretAsync(string secretName, string fieldName = "password", CancellationToken cancellationToken = default);

    /// <summary>Returns <c>true</c> if <paramref name="secretName"/> exists in the provider.</summary>
    Task<bool> SecretExistsAsync(string secretName, CancellationToken cancellationToken = default);
}
