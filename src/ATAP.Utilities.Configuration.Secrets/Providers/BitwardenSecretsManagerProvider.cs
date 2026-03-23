namespace ATAP.Utilities.Configuration.Secrets.Providers;

/// <summary>
/// Stub secret provider for Bitwarden Secrets Manager (not yet implemented).
/// </summary>
/// <remarks>
/// <para>
/// To implement this provider:
/// <list type="number">
///   <item>Add the <c>Bitwarden.Sdk</c> NuGet package.</item>
///   <item>
///     Create a machine account in the Bitwarden Secrets Manager console and assign it
///     read access to the relevant projects.
///   </item>
///   <item>
///     Store the generated access token in the environment variable named by
///     <see cref="BitwardenSecretsManagerOptions.AccessTokenEnvVarName"/>
///     (default: <c>BWS_ACCESS_TOKEN</c>).
///   </item>
///   <item>
///     Replace the <see cref="GetSecretAsync"/> body with SDK calls using
///     <c>BitwardenClient</c> and the access token.
///   </item>
/// </list>
/// </para>
/// <para>
/// Until this provider is implemented, do not register it via
/// <see cref="SecretProvidersBuilder.AddBitwardenSecretsManager"/>.
/// </para>
/// </remarks>
public sealed class BitwardenSecretsManagerProvider : ISecretProvider
{
  private readonly BitwardenSecretsManagerOptions _opts;

  /// <summary>Initializes a new instance with the supplied options.</summary>
  public BitwardenSecretsManagerProvider(BitwardenSecretsManagerOptions opts) => _opts = opts;

  /// <inheritdoc />
  public string ProviderName => "BitwardenSecretsManager";

  /// <inheritdoc />
  /// <remarks>
  /// Returns true when the access token environment variable is set, anticipating
  /// future implementation. The provider will still throw <see cref="NotImplementedException"/>
  /// from <see cref="GetSecretAsync"/> until the body is written.
  /// </remarks>
  public bool IsAvailable() =>
    !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(_opts.AccessTokenEnvVarName));

  /// <inheritdoc />
  /// <exception cref="NotImplementedException">
  /// Always thrown. Implement this method using the Bitwarden.Sdk NuGet package.
  /// </exception>
  public Task<string?> GetSecretAsync(
    string secretName, string? fieldName, CancellationToken cancellationToken = default) =>
    throw new NotImplementedException(
      $"BitwardenSecretsManagerProvider is not yet implemented. " +
      $"Add the Bitwarden.Sdk NuGet package and implement this method. " +
      $"Required env var: {_opts.AccessTokenEnvVarName}.");
}
