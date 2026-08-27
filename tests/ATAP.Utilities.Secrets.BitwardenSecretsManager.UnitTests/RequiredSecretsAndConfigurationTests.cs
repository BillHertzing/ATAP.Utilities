using System.Text.Json;
using ATAP.Utilities.Secrets.BitwardenSecretsManager;
using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

public sealed class RequiredSecretsAndConfigurationTests
{
  private const string ProjectId = "11111111-1111-1111-1111-111111111111";
  private const string DatabaseSecretId = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
  private const string ApiSecretId = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";

  [Fact]
  public async Task ValidateRequiredSecretsAsync_AllExactNamesPresent_GetsEachSecretById()
  {
    var options = ValidOptions();
    options.RequiredSecretNames = new HashSet<string>(["Database.Password", "Api.Key"], StringComparer.Ordinal);
    options.SecretIdsByName["Database.Password"] = DatabaseSecretId;
    options.SecretIdsByName["Api.Key"] = ApiSecretId;
    var runner = new FakeRunner(arguments => arguments[2] == DatabaseSecretId
      ? SecretJson(DatabaseSecretId, "Database.Password", "db-value")
      : SecretJson(ApiSecretId, "Api.Key", "api-value"));
    var provider = new BitwardenSecretsManagerProvider(options, runner);

    await provider.ValidateRequiredSecretsAsync();

    Assert.Equal(2, runner.CallCount);
    Assert.All(runner.AllArguments, arguments => Assert.Equal("get", arguments[1]));
  }

  [Fact]
  public void ProviderConstructor_RequiredSecretWithoutId_ThrowsInvalidConfiguration()
  {
    var options = ValidOptions();
    options.RequiredSecretNames.Add("Database.Password");
    var error = Assert.Throws<BwsException>(() => new BitwardenSecretsManagerProvider(options, new FakeRunner(_ => "")));

    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
  }

  [Theory]
  [InlineData("", "Secret", "Other")]
  [InlineData("Key", "", "Other")]
  [InlineData("Key", "Secret", "key")]
  public async Task GetMappedSecretsAsync_InvalidMapping_ThrowsInvalidConfiguration(
    string firstConfigurationKey,
    string firstSecretName,
    string secondConfigurationKey)
  {
    var provider = new BitwardenSecretsManagerProvider(ValidOptions(), new FakeRunner(_ => throw new InvalidOperationException()));
    BwsSecretMapping[] mappings =
    [
      new(firstConfigurationKey, firstSecretName),
      new(secondConfigurationKey, "OtherSecret"),
    ];

    var error = await Assert.ThrowsAsync<BwsException>(() => provider.GetMappedSecretsAsync(mappings));

    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
  }

  [Fact]
  public async Task GetMappedSecretsAsync_RequiredMissingFailsAndOptionalMissingIsOmitted()
  {
    var options = ValidOptions();
    options.SecretIdsByName["Present"] = DatabaseSecretId;
    var provider = new BitwardenSecretsManagerProvider(options, new FakeRunner(_ => SecretJson(DatabaseSecretId, "Present", "value")));

    var optional = await provider.GetMappedSecretsAsync([new("Optional", "Missing", Required: false)]);
    var required = await Assert.ThrowsAsync<BwsException>(() => provider.GetMappedSecretsAsync([new("Required", "Missing")]));

    Assert.Empty(optional);
    Assert.Equal(BwsFailureKind.InvalidConfiguration, required.Kind);
  }

  [Fact]
  public async Task ConfigurationLoader_MapsFieldsAndSecretsWithOneCliCall()
  {
    var options = ValidOptions();
    options.SecretIdsByName["Database"] = DatabaseSecretId;
    options.SecretIdsByName["Api.Key"] = ApiSecretId;
    var runner = new FakeRunner(arguments => arguments[2] == DatabaseSecretId
      ? SecretJson(DatabaseSecretId, "Database", "{\"username\":\"ace\",\"port\":1433}")
      : SecretJson(ApiSecretId, "Api.Key", "api-value"));
    var provider = new BitwardenSecretsManagerProvider(options, runner);
    var loader = new BitwardenSecretsManagerConfigurationLoader(provider);
    var builder = new ConfigurationBuilder();

    await builder.AddBitwardenSecretsManagerConfigurationAsync(loader,
    [
      new("Connection:User", "Database", "username"),
      new("Connection:Port", "Database", "port"),
      new("Api:Key", "Api.Key"),
      new("Optional", "Absent", Required: false),
    ]);
    var configuration = builder.Build();

    Assert.Equal("ace", configuration["Connection:User"]);
    Assert.Equal("1433", configuration["Connection:Port"]);
    Assert.Equal("api-value", configuration["Api:Key"]);
    Assert.Null(configuration["Optional"]);
    Assert.Equal(2, runner.CallCount);
  }

  [Fact]
  public async Task GetMappedSecretsAsync_CancellationIsForwardedWithoutTranslation()
  {
    using var cancellation = new CancellationTokenSource();
    cancellation.Cancel();
    var options = ValidOptions();
    options.SecretIdsByName["Secret"] = DatabaseSecretId;
    var runner = new FakeRunner(_ => "", throwOnCancellation: true);
    var provider = new BitwardenSecretsManagerProvider(options, runner);

    await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
      provider.GetMappedSecretsAsync([new("Key", "Secret")], cancellation.Token));

    Assert.Equal(cancellation.Token, runner.ObservedCancellationToken);
  }

  private static BitwardenSecretsManagerOptions ValidOptions() => new()
  {
    ApplicationId = "AceCommander",
    ProjectId = ProjectId,
    ProjectName = "AceCommander",
    BwsExecutablePath = Path.Combine(Path.GetTempPath(), "bws.exe"),
  };

  private static string SecretJson(string id, string key, string value) =>
    JsonSerializer.Serialize(new { id, projectId = ProjectId, key, value });

  private sealed class FakeRunner(Func<IReadOnlyList<string>, string> outputFactory, bool throwOnCancellation = false) : IBwsProcessRunner
  {
    public int CallCount { get; private set; }
    public IReadOnlyList<string> Arguments { get; private set; } = [];
    public List<IReadOnlyList<string>> AllArguments { get; } = [];
    public CancellationToken ObservedCancellationToken { get; private set; }

    public Task<BwsProcessResult> RunAsync(IReadOnlyList<string> arguments, CancellationToken cancellationToken = default)
    {
      CallCount++;
      Arguments = arguments.ToArray();
      AllArguments.Add(Arguments);
      ObservedCancellationToken = cancellationToken;
      if (throwOnCancellation) cancellationToken.ThrowIfCancellationRequested();
      return Task.FromResult(new BwsProcessResult(0, outputFactory(arguments)));
    }
  }
}
