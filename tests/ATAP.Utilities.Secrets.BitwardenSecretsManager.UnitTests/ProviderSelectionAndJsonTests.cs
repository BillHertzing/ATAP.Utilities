using System.Text.Json;
using ATAP.Utilities.Secrets.BitwardenSecretsManager;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

public sealed class ProviderSelectionAndJsonTests
{
  private const string ProjectId = "abcdefab-cdef-abcd-efab-cdefabcdefab";
  private const string SecretId = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
  private const string SyntheticValue = "synthetic-value-15-152-a";

  [Fact]
  public async Task GetSecretAsync_UsesOrdinalExactNameInsteadOfCaseOrSubstring()
  {
    var provider = CreateProvider(SecretJson(ProjectId, "Database.Password", SyntheticValue), "Database.Password");

    var exact = await provider.GetSecretAsync("Database.Password");
    var caseError = await Assert.ThrowsAsync<BwsException>(() => provider.GetSecretAsync("DATABASE.PASSWORD"));
    var substringError = await Assert.ThrowsAsync<BwsException>(() => provider.GetSecretAsync("Database.Pass"));

    Assert.Equal(SyntheticValue, exact);
    Assert.Equal(BwsFailureKind.InvalidConfiguration, caseError.Kind);
    Assert.Equal(BwsFailureKind.InvalidConfiguration, substringError.Kind);
  }

  [Fact]
  public async Task GetSecretAsync_MismatchedNameOrMissingMapping_FailsClosed()
  {
    var mismatchedProvider = CreateProvider(SecretJson(ProjectId, "Other", "value"), "Key");
    var missingProvider = CreateProvider(SecretJson(ProjectId, "Other", "value"));

    var mismatched = await Assert.ThrowsAsync<BwsException>(() => mismatchedProvider.GetSecretAsync("Key"));
    var missing = await Assert.ThrowsAsync<BwsException>(() => missingProvider.GetSecretAsync("Key"));

    Assert.Equal(BwsFailureKind.CliJsonInvalid, mismatched.Kind);
    Assert.Equal(BwsFailureKind.InvalidConfiguration, missing.Kind);
  }

  [Fact]
  public async Task GetSecretAsync_ProjectComparisonIsOrdinalIgnoreCaseButRejectsForeignProject()
  {
    var caseVariantProvider = CreateProvider(SecretJson(ProjectId.ToUpperInvariant(), "Key", SyntheticValue), "Key");
    var foreignProvider = CreateProvider(SecretJson("11111111-1111-1111-1111-111111111111", "Key", SyntheticValue), "Key");

    var accepted = await caseVariantProvider.GetSecretAsync("Key");
    var rejected = await Assert.ThrowsAsync<BwsException>(() => foreignProvider.GetSecretAsync("Key"));

    Assert.Equal(SyntheticValue, accepted);
    Assert.Equal(BwsFailureKind.CliJsonInvalid, rejected.Kind);
  }

  [Theory]
  [InlineData("{}")]
  [InlineData("42")]
  [InlineData("null")]
  [InlineData("[")]
  [InlineData("[] trailing")]
  public async Task GetSecretAsync_NonListOrMalformedCliJson_ThrowsCliJsonInvalid(string output)
  {
    var provider = CreateProvider(output, "Key");

    var error = await Assert.ThrowsAsync<BwsException>(() => provider.GetSecretAsync("Key"));

    Assert.Equal(BwsFailureKind.CliJsonInvalid, error.Kind);
    Assert.DoesNotContain(output, error.Message, StringComparison.Ordinal);
  }

  [Theory]
  [InlineData("projectId")]
  [InlineData("key")]
  [InlineData("value")]
  public async Task GetSecretAsync_DuplicateCliObjectMember_ThrowsCliJsonInvalid(string duplicateMember)
  {
    var members = new List<string>
    {
      $"\"id\":\"{SecretId}\"",
      $"\"projectId\":\"{ProjectId}\"",
      "\"key\":\"Key\"",
      "\"value\":\"value\"",
    };
    members.Add(duplicateMember switch
    {
      "projectId" => $"\"projectId\":\"{ProjectId}\"",
      "key" => "\"key\":\"Key\"",
      "value" => "\"value\":\"other\"",
      _ => throw new ArgumentOutOfRangeException(nameof(duplicateMember)),
    });
    var provider = CreateProvider($"{{{string.Join(',', members)}}}", "Key");

    var error = await Assert.ThrowsAsync<BwsException>(() => provider.GetSecretAsync("Key"));

    Assert.Equal(BwsFailureKind.CliJsonInvalid, error.Kind);
  }

  [Theory]
  [InlineData("{\"field\":\"text\"}", "text")]
  [InlineData("{\"field\":17}", "17")]
  [InlineData("{\"field\":true}", "true")]
  [InlineData("{\"field\":null}", "null")]
  [InlineData("{\"field\":{\"nested\":1}}", "{\"nested\":1}")]
  [InlineData("{\"field\":[1,2]}", "[1,2]")]
  public async Task GetSecretAsync_JsonObjectField_ReturnsStringOrCanonicalRawValue(string secretValue, string expected)
  {
    var provider = CreateProvider(SecretJson(ProjectId, "Structured", secretValue), "Structured");

    var actual = await provider.GetSecretAsync("Structured", "field");

    Assert.Equal(expected, actual);
  }

  [Theory]
  [InlineData("42")]
  [InlineData("null")]
  [InlineData("malformed {")]
  [InlineData("{\"different\":1}")]
  public async Task GetSecretAsync_DefaultFieldPolicy_ReturnsRawScalarNullMalformedOrMissingValue(string secretValue)
  {
    var provider = CreateProvider(SecretJson(ProjectId, "Structured", secretValue), "Structured");

    var actual = await provider.GetSecretAsync("Structured", "field");

    Assert.Equal(secretValue, actual);
  }

  [Theory]
  [InlineData("42")]
  [InlineData("null")]
  [InlineData("malformed {")]
  [InlineData("{\"Field\":1}")]
  public async Task GetSecretAsync_StrictFieldPolicy_RejectsScalarNullMalformedOrCaseMismatch(string secretValue)
  {
    var options = ValidOptions();
    options.ReturnRawValueWhenFieldMissing = false;
    options.SecretIdsByName["Structured"] = SecretId;
    var provider = new BitwardenSecretsManagerProvider(options, new FakeRunner(SecretJson(ProjectId, "Structured", secretValue)));

    var error = await Assert.ThrowsAsync<BwsException>(() => provider.GetSecretAsync("Structured", "field"));

    Assert.Equal(BwsFailureKind.SecretFieldMissing, error.Kind);
  }

  [Fact]
  public async Task SecretExistsAsync_UnmappedReturnsFalseButMismatchedResponseFailsClosed()
  {
    var provider = CreateProvider(SecretJson(ProjectId, "Other", "value"), "Key");

    var missing = await provider.SecretExistsAsync("Missing");
    var mismatch = await Assert.ThrowsAsync<BwsException>(() => provider.SecretExistsAsync("Key"));

    Assert.False(missing);
    Assert.Equal(BwsFailureKind.CliJsonInvalid, mismatch.Kind);
  }

  private static BitwardenSecretsManagerProvider CreateProvider(string output, params string[] mappedNames)
  {
    var options = ValidOptions();
    foreach (var name in mappedNames) options.SecretIdsByName.Add(name, SecretId);
    return new(options, new FakeRunner(output));
  }

  private static BitwardenSecretsManagerOptions ValidOptions() => new()
  {
    ApplicationId = "AceCommander",
    ProjectId = ProjectId,
    ProjectName = "AceCommander",
    BwsExecutablePath = Path.Combine(Path.GetTempPath(), "bws.exe"),
  };

  private static string SecretJson(string projectId, string key, string value) =>
    JsonSerializer.Serialize(new { id = SecretId, projectId, key, value });

  private sealed class FakeRunner(string output) : IBwsProcessRunner
  {
    public Task<BwsProcessResult> RunAsync(IReadOnlyList<string> arguments, CancellationToken cancellationToken = default) =>
      Task.FromResult(new BwsProcessResult(0, output));
  }
}
