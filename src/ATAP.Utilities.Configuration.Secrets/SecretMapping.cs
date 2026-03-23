namespace ATAP.Utilities.Configuration.Secrets;

/// <summary>
/// Maps a named secret in a provider's store to an <see cref="Microsoft.Extensions.Configuration.IConfiguration"/> key path.
/// </summary>
/// <param name="SecretName">
/// The name used to look up the secret in the provider (e.g. "AceCommander DB Connection").
/// </param>
/// <param name="ConfigurationKey">
/// The IConfiguration key the retrieved value is written to (e.g. "ConnectionStrings:ATAPUtilities").
/// </param>
/// <param name="FieldName">
/// Optional field within the secret item. When null the provider's default field is used.
/// For Bitwarden Password Manager: null maps to the password field; any other value names a custom field.
/// </param>
public record SecretMapping(string SecretName, string ConfigurationKey, string? FieldName = null);
