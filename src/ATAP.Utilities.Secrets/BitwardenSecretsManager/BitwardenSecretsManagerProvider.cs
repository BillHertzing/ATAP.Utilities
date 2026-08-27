using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public sealed class BitwardenSecretsManagerProvider : SecretsAbstract
{
  private readonly BitwardenSecretsManagerOptions _options;
  private readonly IBwsProcessRunner _runner;
  public BitwardenSecretsManagerProvider(BitwardenSecretsManagerOptions options, IBwsProcessRunner runner)
  { _options = options; _runner = runner; _options.Validate(); Options = new SecretsOptions(options); }

  public override string ProviderName => "Bitwarden Secrets Manager";
  public override bool IsAvailable() => File.Exists(_options.BwsExecutablePath);

  public override async Task<string?> GetSecretAsync(string secretName, string? fieldName = null, CancellationToken cancellationToken = default)
  {
    ArgumentException.ThrowIfNullOrWhiteSpace(secretName);
    var secret = await GetSecretByNameAsync(secretName, required: true, cancellationToken).ConfigureAwait(false);
    return SelectField(secret.Value, secretName, fieldName);
  }

  public async Task<IReadOnlyDictionary<string, string?>> GetMappedSecretsAsync(IEnumerable<BwsSecretMapping> mappings, CancellationToken cancellationToken = default)
  {
    ArgumentNullException.ThrowIfNull(mappings);
    var mappingArray = mappings.ToArray();
    if (mappingArray.Any(x => string.IsNullOrWhiteSpace(x.ConfigurationKey) || string.IsNullOrWhiteSpace(x.SecretName)) ||
        mappingArray.Select(x => x.ConfigurationKey).Distinct(StringComparer.OrdinalIgnoreCase).Count() != mappingArray.Length)
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "Configuration keys and SecretNames must be non-empty and configuration keys must be unique.");
    var result = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
    var secrets = new Dictionary<string, BwsSecret>(StringComparer.Ordinal);
    foreach (var mapping in mappingArray)
    {
      if (!secrets.TryGetValue(mapping.SecretName, out var secret))
      {
        var resolved = await GetSecretByNameAsync(mapping.SecretName, mapping.Required, cancellationToken).ConfigureAwait(false);
        if (resolved is null) continue;
        secret = resolved;
        secrets.Add(mapping.SecretName, secret);
      }
      result.Add(mapping.ConfigurationKey, SelectField(secret.Value, mapping.SecretName, mapping.FieldName));
    }
    return result;
  }

  public async Task ValidateRequiredSecretsAsync(CancellationToken cancellationToken = default)
  {
    foreach (var secretName in _options.RequiredSecretNames)
      _ = await GetSecretByNameAsync(secretName, required: true, cancellationToken).ConfigureAwait(false);
  }

  public override async Task<bool> SecretExistsAsync(string secretName, CancellationToken cancellationToken = default)
  {
    ArgumentException.ThrowIfNullOrWhiteSpace(secretName);
    return await GetSecretByNameAsync(secretName, required: false, cancellationToken).ConfigureAwait(false) is not null;
  }

  private async Task<BwsSecret?> GetSecretByNameAsync(string secretName, bool required, CancellationToken cancellationToken)
  {
    if (!_options.SecretIdsByName.TryGetValue(secretName, out var secretId))
    {
      if (required)
        throw new BwsException(BwsFailureKind.InvalidConfiguration, $"SecretName '{secretName}' does not have an exact Secret ID mapping.");
      return null;
    }

    var result = await _runner.RunAsync(["secret", "get", secretId, "--output", "json", "--color", "never"], cancellationToken).ConfigureAwait(false);
    try
    {
      var utf8 = Encoding.UTF8.GetBytes(result.StandardOutput);
      RejectDuplicateJsonMembers(utf8);
      var secret = JsonSerializer.Deserialize<BwsSecret>(utf8, SerializerOptions);
      if (secret is null || secret.Value is null ||
          !string.Equals(secret.Id, secretId, StringComparison.OrdinalIgnoreCase) ||
          !string.Equals(secret.ProjectId, _options.ProjectId, StringComparison.OrdinalIgnoreCase) ||
          !string.Equals(secret.Key, secretName, StringComparison.Ordinal))
        throw new JsonException();
      return secret;
    }
    catch (JsonException exception)
    {
      throw new BwsException(BwsFailureKind.CliJsonInvalid, "bws returned an invalid or mismatched secret-get response.", exception);
    }
  }

  private string? SelectField(string value, string secretName, string? fieldName)
  {
    if (string.IsNullOrWhiteSpace(fieldName)) return value;
    try
    {
      using var document = JsonDocument.Parse(value);
      if (document.RootElement.ValueKind == JsonValueKind.Object && document.RootElement.TryGetProperty(fieldName, out var field))
        return field.ValueKind == JsonValueKind.String ? field.GetString() : field.GetRawText();
    }
    catch (JsonException exception)
    {
      if (_options.ReturnRawValueWhenFieldMissing) return value;
      throw new BwsException(BwsFailureKind.SecretFieldMissing, $"Field '{fieldName}' was not found in SecretName '{secretName}'.", exception);
    }
    if (_options.ReturnRawValueWhenFieldMissing) return value;
    throw new BwsException(BwsFailureKind.SecretFieldMissing, $"Field '{fieldName}' was not found in SecretName '{secretName}'.");
  }

  private static void RejectDuplicateJsonMembers(ReadOnlySpan<byte> json)
  {
    var reader = new Utf8JsonReader(json, new JsonReaderOptions { AllowTrailingCommas = false, CommentHandling = JsonCommentHandling.Disallow, MaxDepth = 32 });
    var objectMembers = new Stack<HashSet<string>>();
    while (reader.Read())
    {
      if (reader.TokenType == JsonTokenType.StartObject) objectMembers.Push(new HashSet<string>(StringComparer.Ordinal));
      else if (reader.TokenType == JsonTokenType.EndObject) objectMembers.Pop();
      else if (reader.TokenType == JsonTokenType.PropertyName && !objectMembers.Peek().Add(reader.GetString() ?? throw new JsonException())) throw new JsonException("Duplicate JSON member.");
    }
  }

  private static readonly JsonSerializerOptions SerializerOptions = new() { PropertyNameCaseInsensitive = false, UnmappedMemberHandling = JsonUnmappedMemberHandling.Skip };
  private sealed record BwsSecret(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("projectId")] string ProjectId,
    [property: JsonPropertyName("key")] string Key,
    [property: JsonPropertyName("value")] string Value);
}
