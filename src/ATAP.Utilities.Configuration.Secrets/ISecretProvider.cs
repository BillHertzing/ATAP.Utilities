namespace ATAP.Utilities.Configuration.Secrets;

/// <summary>
/// Abstraction over a secret store. Implement this interface to support additional
/// secret providers (e.g., Bitwarden Secrets Manager, Azure Key Vault, HashiCorp Vault).
/// </summary>
public interface ISecretProvider
{
  /// <summary>Human-readable name used in logging and diagnostics.</summary>
  string ProviderName { get; }

  /// <summary>
  /// Returns true if this provider is configured and can be queried.
  /// When false the provider is silently skipped rather than throwing at startup.
  /// </summary>
  bool IsAvailable();

  /// <summary>
  /// Retrieves a secret value by name.
  /// </summary>
  /// <param name="secretName">The name (or item title) of the secret in the provider's store.</param>
  /// <param name="fieldName">
  /// Optional field within the secret item. When null the provider's default field
  /// (e.g. the "password" field in Bitwarden) is used.
  /// </param>
  /// <param name="cancellationToken">Cancellation token.</param>
  /// <returns>The secret value, or null if not found.</returns>
  Task<string?> GetSecretAsync(string secretName, string? fieldName, CancellationToken cancellationToken = default);
}
