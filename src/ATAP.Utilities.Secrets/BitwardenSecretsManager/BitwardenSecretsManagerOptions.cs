using System.ComponentModel.DataAnnotations;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public sealed class BitwardenSecretsManagerOptions
{
  public const string DefaultConfigurationSectionName = "Secrets:BitwardenSecretsManager";

  [Required]
  public string ApplicationId { get; set; } = string.Empty;

  [Required]
  public string ProjectId { get; set; } = string.Empty;

  [Required]
  public string ProjectName { get; set; } = string.Empty;

  public string VaultGroupingId { get; set; } = string.Empty;

  [Required]
  public string BwsExecutablePath { get; set; } = string.Empty;

  public string TrustedBwsSha256 { get; set; } = string.Empty;

  [Range(1, 600)]
  public int TimeoutSeconds { get; set; } = 30;

  [Range(1024, 16 * 1024 * 1024)]
  public int MaximumOutputCharacters { get; set; } = 1024 * 1024;

  public bool ReturnRawValueWhenFieldMissing { get; set; } = true;

  public BwsTokenPurpose TokenPurpose { get; set; } = BwsTokenPurpose.ReadOnly;

  public HashSet<string> RequiredSecretNames { get; set; } = new(StringComparer.Ordinal);

  public Dictionary<string, string> SecretIdsByName { get; set; } = new(StringComparer.Ordinal);

  internal void Validate()
  {
    if (string.IsNullOrWhiteSpace(ApplicationId))
    {
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "A non-empty application ID is required.");
    }

    if (!Guid.TryParse(ProjectId, out _))
    {
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "The Bitwarden Project ID must be a UUID.");
    }

    if (string.IsNullOrWhiteSpace(ProjectName))
    {
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "A Bitwarden Project name is required.");
    }

    if (string.IsNullOrWhiteSpace(VaultGroupingId)) VaultGroupingId = ProjectId;

    if (string.IsNullOrWhiteSpace(BwsExecutablePath) || !Path.IsPathFullyQualified(BwsExecutablePath))
    {
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "The bws executable path must be absolute.");
    }

    if (TimeoutSeconds is < 1 or > 600)
    {
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "The bws timeout must be between 1 and 600 seconds.");
    }

    if (MaximumOutputCharacters is < 1024 or > 16 * 1024 * 1024)
    {
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "The bws output limit is outside the supported range.");
    }

    if (TokenPurpose != BwsTokenPurpose.ReadOnly)
    {
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "Application access supports only a ReadOnly BWS token.");
    }

    if (RequiredSecretNames.Any(string.IsNullOrWhiteSpace) || RequiredSecretNames.Count != RequiredSecretNames.Distinct(StringComparer.Ordinal).Count())
    {
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "Required SecretNames must be non-empty and ordinally unique.");
    }

    if (SecretIdsByName.Any(entry => string.IsNullOrWhiteSpace(entry.Key) || !Guid.TryParse(entry.Value, out _)) ||
        SecretIdsByName.Values.Distinct(StringComparer.OrdinalIgnoreCase).Count() != SecretIdsByName.Count)
    {
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "Secret ID mappings must use non-empty ordinal SecretNames and unique UUID values.");
    }

    if (RequiredSecretNames.Any(secretName => !SecretIdsByName.ContainsKey(secretName)))
    {
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "Every required SecretName must have an exact Secret ID mapping.");
    }
  }
}
