namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public sealed record BwsSecretMapping(
  string ConfigurationKey,
  string SecretName,
  string? FieldName = null,
  bool Required = true);