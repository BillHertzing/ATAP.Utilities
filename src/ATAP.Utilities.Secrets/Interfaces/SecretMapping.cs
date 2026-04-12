namespace ATAP.Utilities.Secrets;

/// <summary>
/// Maps a vault secret (by name and optional field) to a configuration key.
/// </summary>
public record SecretMapping(string SecretName, string? FieldName, string ConfigurationKey);
