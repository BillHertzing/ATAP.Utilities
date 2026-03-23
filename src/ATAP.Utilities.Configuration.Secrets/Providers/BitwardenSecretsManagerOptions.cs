namespace ATAP.Utilities.Configuration.Secrets.Providers;

/// <summary>
/// Options for the Bitwarden Secrets Manager provider.
/// </summary>
/// <remarks>
/// Bitwarden Secrets Manager is a separate product from the Password Manager.
/// It uses machine accounts with access tokens rather than user sessions.
/// See the Bitwarden Secrets Manager documentation for setup instructions.
/// </remarks>
public sealed class BitwardenSecretsManagerOptions
{
  /// <summary>
  /// Name of the environment variable that holds the Bitwarden Secrets Manager
  /// machine-account access token. Defaults to <c>BWS_ACCESS_TOKEN</c>.
  /// The token is generated in the Bitwarden Secrets Manager console when
  /// creating a machine account.
  /// </summary>
  public string AccessTokenEnvVarName { get; set; } = "BWS_ACCESS_TOKEN";
}
