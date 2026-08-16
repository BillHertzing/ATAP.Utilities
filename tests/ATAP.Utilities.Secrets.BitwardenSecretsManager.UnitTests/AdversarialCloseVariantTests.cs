using System.Runtime.Versioning;
using System.Text.Json;
using ATAP.Utilities.Secrets.BitwardenSecretsManager;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

public sealed class AdversarialCloseVariantTests
{
  private const string ProjectId = "abcdefab-cdef-abcd-efab-cdefabcdefab";
  private const string SyntheticValue = "synthetic-close-variant-value";

  [Fact]
  public async Task GetSecretAsync_CaseAndSubstringNeighborsCannotReplaceExactSecretName()
  {
    var provider = CreateProvider(ListJson(
      (ProjectId, "Database.Password", SyntheticValue),
      (ProjectId, "database.password", "case-neighbor"),
      (ProjectId, "Database.Password.Extended", "substring-neighbor")));

    Assert.Equal(SyntheticValue, await provider.GetSecretAsync("Database.Password"));
    foreach (var nearVariant in new[] { "DATABASE.PASSWORD", "Database.Pass", "Password" })
    {
      var error = await Assert.ThrowsAsync<BwsException>(() => provider.GetSecretAsync(nearVariant));
      Assert.Equal(BwsFailureKind.SecretMissing, error.Kind);
    }
  }

  [Fact]
  public async Task GetSecretAsync_DuplicateNameAcrossVisibleProjectsFailsClosed()
  {
    var provider = CreateProvider(ListJson(
      (ProjectId, "Shared.Name", SyntheticValue),
      ("11111111-1111-1111-1111-111111111111", "Shared.Name", "foreign-project-value")));

    var error = await Assert.ThrowsAsync<BwsException>(() => provider.GetSecretAsync("Shared.Name"));

    Assert.Equal(BwsFailureKind.CliJsonInvalid, error.Kind);
    Assert.DoesNotContain(SyntheticValue, error.ToString(), StringComparison.Ordinal);
    Assert.DoesNotContain("foreign-project-value", error.ToString(), StringComparison.Ordinal);
  }

  [Theory]
  [InlineData("{\"field\":17}", "17")]
  [InlineData("{\"field\":{\"nested\":1}}", "{\"nested\":1}")]
  [InlineData("{\"field\":null}", "null")]
  [InlineData("{\"field\":[1,2]}", "[1,2]")]
  public async Task GetSecretAsync_JsonScalarObjectNullAndArrayFieldsHaveDeterministicProjection(string value, string expected)
  {
    var provider = CreateProvider(ListJson((ProjectId, "Structured", value)));

    var actual = await provider.GetSecretAsync("Structured", "field");

    Assert.Equal(expected, actual);
  }

  [Fact]
  [SupportedOSPlatform("windows")]
  public async Task AcquireAsync_AbsentServiceAccountProfileAndTokenSlotFailsClosed()
  {
    var absentProgramData = Path.Combine(Path.GetTempPath(), "atap-bws-absent-profile", Guid.NewGuid().ToString("N"));
    var identity = new WindowsTokenTestFixture.TestWindowsIdentity(
      Environment.MachineName.ToUpperInvariant(),
      "svcatapmissingprofile",
      "S-1-5-21-1000-1000-1000-1000",
      absentProgramData);
    var protector = new WindowsTokenTestFixture.ThrowIfCalledProtector();
    var source = new WindowsDpapiBwsReadOnlyAccessTokenSource(
      new WindowsBwsTokenSourceOptions
      {
        ApplicationId = WindowsTokenTestFixture.ApplicationId,
        VaultGroupingId = WindowsTokenTestFixture.VaultGroupingId,
      },
      identity,
      new BwsDpapiEnvelopeReader(protector),
      new PowerShellCredentialCliXmlReader(new DpapiUnprotector()),
      new WindowsTokenTestFixture.AllowingSecurityValidator());

    var error = await Assert.ThrowsAsync<BwsException>(async () => await source.AcquireAsync());

    Assert.Equal(BwsFailureKind.TokenFolderMissing, error.Kind);
    Assert.Equal(0, protector.Calls);
    Assert.False(Directory.Exists(absentProgramData));
  }

  private static BitwardenSecretsManagerProvider CreateProvider(string output) =>
    new(ValidOptions(), new FakeRunner(output));

  private static BitwardenSecretsManagerOptions ValidOptions() => new()
  {
    ApplicationId = "AceCommander",
    ProjectId = ProjectId,
    ProjectName = "AceCommander",
    BwsExecutablePath = Path.Combine(Path.GetTempPath(), "bws.exe"),
  };

  private static string ListJson(params (string ProjectId, string Key, string Value)[] entries) =>
    JsonSerializer.Serialize(entries.Select(entry => new
    {
      projectId = entry.ProjectId,
      key = entry.Key,
      value = entry.Value,
    }));

  private sealed class FakeRunner(string output) : IBwsProcessRunner
  {
    public Task<BwsProcessResult> RunAsync(IReadOnlyList<string> arguments, CancellationToken cancellationToken = default) =>
      Task.FromResult(new BwsProcessResult(0, output));
  }
}
