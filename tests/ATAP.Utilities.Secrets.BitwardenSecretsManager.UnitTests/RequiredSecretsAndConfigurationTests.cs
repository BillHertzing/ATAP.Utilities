using System.Text.Json;
using ATAP.Utilities.Secrets.BitwardenSecretsManager;
using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

public sealed class RequiredSecretsAndConfigurationTests
{
  private const string ProjectId = "11111111-1111-1111-1111-111111111111";

  [Fact]
  public async Task ValidateRequiredSecretsAsync_AllExactNamesPresent_ListsProjectOnce()
  {
    var options = ValidOptions();
    options.RequiredSecretNames = new HashSet<string>(["Database.Password", "Api.Key"], StringComparer.Ordinal);
    var runner = new FakeRunner(ListJson(("Database.Password", "db-value"), ("Api.Key", "api-value")));
    var provider = new BitwardenSecretsManagerProvider(options, runner);

    await provider.ValidateRequiredSecretsAsync();

    Assert.Equal(1, runner.CallCount);
    Assert.Equal(["secret", "list", ProjectId, "--output", "json", "--color", "never"], runner.Arguments);
  }

  [Fact]
  public async Task ValidateRequiredSecretsAsync_MissingOrCaseVariant_ThrowsSecretMissing()
  {
    var options = ValidOptions();
    options.RequiredSecretNames.Add("Database.Password");
    var provider = new BitwardenSecretsManagerProvider(options, new FakeRunner(ListJson(("database.password", "nearby"))));

    var error = await Assert.ThrowsAsync<BwsException>(() => provider.ValidateRequiredSecretsAsync());

    Assert.Equal(BwsFailureKind.SecretMissing, error.Kind);
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
    var provider = new BitwardenSecretsManagerProvider(ValidOptions(), new FakeRunner("[]"));
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
    var provider = new BitwardenSecretsManagerProvider(ValidOptions(), new FakeRunner(ListJson(("Present", "value"))));

    var optional = await provider.GetMappedSecretsAsync([new("Optional", "Missing", Required: false)]);
    var required = await Assert.ThrowsAsync<BwsException>(() => provider.GetMappedSecretsAsync([new("Required", "Missing")]));

    Assert.Empty(optional);
    Assert.Equal(BwsFailureKind.SecretMissing, required.Kind);
  }

  [Fact]
  public async Task ConfigurationLoader_MapsFieldsAndSecretsWithOneCliCall()
  {
    var runner = new FakeRunner(ListJson(
      ("Database", "{\"username\":\"ace\",\"port\":1433}"),
      ("Api.Key", "api-value")));
    var provider = new BitwardenSecretsManagerProvider(ValidOptions(), runner);
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
    Assert.Equal(1, runner.CallCount);
  }

  [Fact]
  public async Task GetMappedSecretsAsync_CancellationIsForwardedWithoutTranslation()
  {
    using var cancellation = new CancellationTokenSource();
    cancellation.Cancel();
    var runner = new FakeRunner("[]", throwOnCancellation: true);
    var provider = new BitwardenSecretsManagerProvider(ValidOptions(), runner);

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

  private static string ListJson(params (string Key, string Value)[] entries) =>
    JsonSerializer.Serialize(entries.Select(entry => new
    {
      projectId = ProjectId,
      key = entry.Key,
      value = entry.Value,
    }));

  private sealed class FakeRunner(string output, bool throwOnCancellation = false) : IBwsProcessRunner
  {
    public int CallCount { get; private set; }
    public IReadOnlyList<string> Arguments { get; private set; } = [];
    public CancellationToken ObservedCancellationToken { get; private set; }

    public Task<BwsProcessResult> RunAsync(IReadOnlyList<string> arguments, CancellationToken cancellationToken = default)
    {
      CallCount++;
      Arguments = arguments.ToArray();
      ObservedCancellationToken = cancellationToken;
      if (throwOnCancellation) cancellationToken.ThrowIfCancellationRequested();
      return Task.FromResult(new BwsProcessResult(0, output));
    }
  }
}
