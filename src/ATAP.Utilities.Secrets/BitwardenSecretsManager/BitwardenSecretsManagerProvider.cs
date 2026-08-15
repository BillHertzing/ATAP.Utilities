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
    var secret = SelectOne(await ListProjectSecretsAsync(cancellationToken).ConfigureAwait(false), secretName, required: true)!;
    return SelectField(secret.Value, secretName, fieldName);
  }

  public async Task<IReadOnlyDictionary<string, string?>> GetMappedSecretsAsync(IEnumerable<BwsSecretMapping> mappings, CancellationToken cancellationToken = default)
  {
    ArgumentNullException.ThrowIfNull(mappings);
    var mappingArray = mappings.ToArray();
    if (mappingArray.Any(x => string.IsNullOrWhiteSpace(x.ConfigurationKey) || string.IsNullOrWhiteSpace(x.SecretName)) ||
        mappingArray.Select(x => x.ConfigurationKey).Distinct(StringComparer.OrdinalIgnoreCase).Count() != mappingArray.Length)
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "Configuration keys and SecretNames must be non-empty and configuration keys must be unique.");
    var secrets = await ListProjectSecretsAsync(cancellationToken).ConfigureAwait(false);
    var result = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
    foreach (var mapping in mappingArray)
    {
      var secret = SelectOne(secrets, mapping.SecretName, mapping.Required);
      if (secret is not null) result.Add(mapping.ConfigurationKey, SelectField(secret.Value, mapping.SecretName, mapping.FieldName));
    }
    return result;
  }

  public async Task ValidateRequiredSecretsAsync(CancellationToken cancellationToken = default)
  {
    var secrets = await ListProjectSecretsAsync(cancellationToken).ConfigureAwait(false);
    foreach (var secretName in _options.RequiredSecretNames) _ = SelectOne(secrets, secretName, required: true);
  }

  public override async Task<bool> SecretExistsAsync(string secretName, CancellationToken cancellationToken = default)
  {
    ArgumentException.ThrowIfNullOrWhiteSpace(secretName);
    return SelectOne(await ListProjectSecretsAsync(cancellationToken).ConfigureAwait(false), secretName, required: false) is not null;
  }

  private BwsSecret? SelectOne(IReadOnlyList<BwsSecret> secrets, string secretName, bool required)
  {
    var matches = secrets.Where(secret => string.Equals(secret.Key, secretName, StringComparison.Ordinal)).ToArray();
    if (matches.Length == 0 && required) throw new BwsException(BwsFailureKind.SecretMissing, $"SecretName '{secretName}' was not found in the configured project.");
    if (matches.Length > 1) throw new BwsException(BwsFailureKind.SecretDuplicate, $"SecretName '{secretName}' is not unique in the configured project.");
    return matches.SingleOrDefault();
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
    catch (JsonException) when (_options.ReturnRawValueWhenFieldMissing) { return value; }
    if (_options.ReturnRawValueWhenFieldMissing) return value;
    throw new BwsException(BwsFailureKind.SecretFieldMissing, $"Field '{fieldName}' was not found in SecretName '{secretName}'.");
  }

  private async Task<IReadOnlyList<BwsSecret>> ListProjectSecretsAsync(CancellationToken cancellationToken)
  {
    var result = await _runner.RunAsync(["secret", "list", _options.ProjectId, "--output", "json", "--color", "no"], cancellationToken).ConfigureAwait(false);
    try
    {
      var utf8 = Encoding.UTF8.GetBytes(result.StandardOutput);
      RejectDuplicateJsonMembers(utf8);
      var secrets = JsonSerializer.Deserialize<List<BwsSecret>>(utf8, SerializerOptions);
      if (secrets is null || secrets.Any(secret => string.IsNullOrEmpty(secret.Key) || secret.Value is null) ||
          secrets.Any(secret => !string.Equals(secret.ProjectId, _options.ProjectId, StringComparison.OrdinalIgnoreCase))) throw new JsonException();
      return secrets;
    }
    catch (JsonException exception) { throw new BwsException(BwsFailureKind.CliJsonInvalid, "bws returned an invalid secret-list response.", exception); }
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
  private sealed record BwsSecret([property: JsonPropertyName("projectId")] string ProjectId, [property: JsonPropertyName("key")] string Key, [property: JsonPropertyName("value")] string Value);
}