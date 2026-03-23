namespace ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden;

/// <summary>
/// Maps a .NET configuration key to a Bitwarden vault item and field.
/// </summary>
/// <param name="ConfigKey">The configuration key that will appear in <c>IConfiguration</c>.</param>
/// <param name="BwItemName">The Bitwarden vault item name (vault display name).</param>
/// <param name="BwFieldName">
/// The Bitwarden field to extract.
/// <c>"password"</c> targets the built-in Password field;
/// any other value targets a custom field by that name (case-insensitive).
/// </param>
public sealed record BitwardenSecretMapping(string ConfigKey, string BwItemName, string BwFieldName = "password");
