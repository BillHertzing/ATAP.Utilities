using ATAP.Utilities.Secrets.BitwardenSecretsManager;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;
using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

public sealed class BitwardenSecretsManagerProviderTests
{
  private const string ProjectId = "11111111-1111-1111-1111-111111111111";
  private const string SecretId = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";

  [Fact]
  public async Task GetSecretAsync_UsesProjectAndExactOrdinalSecretName()
  {
    var runner = new FakeRunner(SecretJson("Database.Password", "correct"));
    var provider = CreateProvider(runner, "Database.Password");
    Assert.Equal("correct", await provider.GetSecretAsync("Database.Password"));
    Assert.Equal(new[] { "secret", "get", SecretId, "--output", "json", "--color", "never" }, runner.Arguments);
  }

  [Fact]
  public async Task GetSecretAsync_CaseMismatchIsMissing()
  {
    var provider = CreateProvider(new FakeRunner(SecretJson("Database.Password", "value")), "database.password");
    var error = await Assert.ThrowsAsync<BwsException>(() => provider.GetSecretAsync("database.password"));
    Assert.Equal(BwsFailureKind.CliJsonInvalid, error.Kind);
  }

  [Fact]
  public async Task GetSecretAsync_RejectsMismatchedSecretId()
  {
    var json = $$"""{"id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","projectId":"{{ProjectId}}","key":"Key","value":"value"}""";
    var error = await Assert.ThrowsAsync<BwsException>(() => CreateProvider(new FakeRunner(json), "Key").GetSecretAsync("Key"));
    Assert.Equal(BwsFailureKind.CliJsonInvalid, error.Kind);
  }

  [Fact]
  public async Task GetSecretAsync_RejectsSecretFromDifferentProject()
  {
    var json = $$"""{"id":"{{SecretId}}","projectId":"22222222-2222-2222-2222-222222222222","key":"Key","value":"value"}""";
    var error = await Assert.ThrowsAsync<BwsException>(() => CreateProvider(new FakeRunner(json), "Key").GetSecretAsync("Key"));
    Assert.Equal(BwsFailureKind.CliJsonInvalid, error.Kind);
  }

  [Fact]
  public async Task GetSecretAsync_ReturnsNamedJsonField()
  {
    var encoded = "{\"username\":\"ace\",\"port\":1433}".Replace("\"", "\\\"");
    var json = $$"""{"id":"{{SecretId}}","projectId":"{{ProjectId}}","key":"Database","value":"{{encoded}}"}""";
    var provider = CreateProvider(new FakeRunner(json), "Database");
    Assert.Equal("ace", await provider.GetSecretAsync("Database", "username"));
    Assert.Equal("1433", await provider.GetSecretAsync("Database", "port"));
  }

  [Fact]
  public async Task SecretExistsAsync_ReturnsDeterministicResult()
  {
    var provider = CreateProvider(new FakeRunner(SecretJson("Present", "value")), "Present");
    Assert.True(await provider.SecretExistsAsync("Present"));
    Assert.False(await provider.SecretExistsAsync("Absent"));
  }

  [Fact]
  public async Task GetSecretAsync_RejectsDuplicateJsonMember()
  {
    var json = $$"""{"id":"{{SecretId}}","projectId":"{{ProjectId}}","key":"Key","key":"Other","value":"value"}""";
    var error = await Assert.ThrowsAsync<BwsException>(() => CreateProvider(new FakeRunner(json), "Key").GetSecretAsync("Key"));
    Assert.Equal(BwsFailureKind.CliJsonInvalid, error.Kind);
  }

  [Fact]
  public async Task ConfigurationLoader_GetsEachDistinctConfiguredSecretOnce()
  {
    var runner = new FakeRunner(SecretJson("One", "first"));
    var loader = new BitwardenSecretsManagerConfigurationLoader(CreateProvider(runner, "One"));
    var builder = new ConfigurationBuilder();
    await builder.AddBitwardenSecretsManagerConfigurationAsync(loader, [new("A", "One"), new("B", "One"), new("Optional", "Missing", Required: false)]);
    var configuration = builder.Build();
    Assert.Equal("first", configuration["A"]); Assert.Equal("first", configuration["B"]); Assert.Null(configuration["Optional"]); Assert.Equal(1, runner.CallCount);
  }
  [Fact]
  public async Task WindowsTokenSource_RejectsUnsafeLegacyTokenLabelBeforeFileAccess()
  {
    var options = new WindowsBwsTokenSourceOptions
    {
      ApplicationId = "AceCommander",
      VaultGroupingId = ProjectId,
      LegacyTokenLabel = @"..\outside",
    };
    var source = new WindowsDpapiBwsReadOnlyAccessTokenSource(
      options,
      new FakeWindowsIdentityContext(),
      new BwsDpapiEnvelopeReader(new FakeDpapiProtector()),
      new PowerShellCredentialCliXmlReader(new FakeDpapiUnprotector()),
      new FakePathSecurityValidator());

    var error = await Assert.ThrowsAsync<BwsException>(async () => await source.AcquireAsync());

    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
  }

  private static BitwardenSecretsManagerProvider CreateProvider(FakeRunner runner, params string[] secretNames) => new(Options(secretNames), runner);
  private static BitwardenSecretsManagerOptions Options(IEnumerable<string> secretNames)
  {
    var options = new BitwardenSecretsManagerOptions { ApplicationId = "AceCommander", ProjectId = ProjectId, ProjectName = "AceCommander", BwsExecutablePath = @"C:\tools\bws.exe" };
    foreach (var secretName in secretNames) options.SecretIdsByName.Add(secretName, SecretId);
    return options;
  }
  private static string SecretJson(string key, string value) =>
    $$"""{"id":"{{SecretId}}","projectId":"{{ProjectId}}","key":"{{key}}","value":"{{value}}"}""";

  private sealed class FakeRunner(string json) : IBwsProcessRunner
  {
    public IReadOnlyList<string> Arguments { get; private set; } = [];
    public int CallCount { get; private set; }
    public Task<BwsProcessResult> RunAsync(IReadOnlyList<string> arguments, CancellationToken cancellationToken = default)
    { Arguments = arguments.ToArray(); CallCount++; return Task.FromResult(new BwsProcessResult(0, json)); }
  }

  private sealed class FakeWindowsIdentityContext : IWindowsIdentityContext
  {
    public string MachineName => "HOST01";
    public string SamAccountName => "svcbuilder";
    public string SecurityIdentifier => "S-1-5-21-1";
    public string ProgramDataDirectory => @"C:\ProgramData";
  }

  private sealed class FakeDpapiProtector : IBwsDpapiProtector
  {
    public byte[] UnprotectForCurrentUser(byte[] ciphertext, byte[] entropy) => throw new NotSupportedException();
  }

  private sealed class FakeDpapiUnprotector : IDpapiUnprotector
  {
    public byte[] UnprotectForCurrentUser(byte[] ciphertext) => throw new NotSupportedException();
  }

  private sealed class FakePathSecurityValidator : IWindowsTokenPathSecurityValidator
  {
    public void Validate(string directoryPath, string tokenFilePath, string currentSid) => throw new NotSupportedException();
  }
}
