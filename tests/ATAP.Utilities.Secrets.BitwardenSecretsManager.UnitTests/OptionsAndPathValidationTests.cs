using ATAP.Utilities.Secrets.BitwardenSecretsManager;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

public sealed class OptionsAndPathValidationTests
{
  private const string ProjectId = "11111111-1111-1111-1111-111111111111";

  [Theory]
  [InlineData(1, 1024)]
  [InlineData(600, 16 * 1024 * 1024)]
  public void ProviderConstructor_ValidBoundaryOptions_DefaultsVaultGrouping(int timeoutSeconds, int maximumOutputCharacters)
  {
    var options = ValidProviderOptions();
    options.TimeoutSeconds = timeoutSeconds;
    options.MaximumOutputCharacters = maximumOutputCharacters;

    _ = new BitwardenSecretsManagerProvider(options, new UnusedRunner());

    Assert.Equal(ProjectId, options.VaultGroupingId);
  }

  [Theory]
  [InlineData("ApplicationId")]
  [InlineData("ProjectId")]
  [InlineData("ProjectName")]
  [InlineData("BwsExecutablePath")]
  public void ProviderConstructor_RequiredOrQualifiedOptionInvalid_ThrowsTypedFailure(string optionName)
  {
    var options = ValidProviderOptions();
    switch (optionName)
    {
      case "ApplicationId": options.ApplicationId = " "; break;
      case "ProjectId": options.ProjectId = "not-a-project-uuid"; break;
      case "ProjectName": options.ProjectName = " "; break;
      case "BwsExecutablePath": options.BwsExecutablePath = "bws.exe"; break;
      default: throw new ArgumentOutOfRangeException(nameof(optionName));
    }

    var error = Assert.Throws<BwsException>(() => new BitwardenSecretsManagerProvider(options, new UnusedRunner()));

    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
  }

  [Theory]
  [InlineData(0, 1024)]
  [InlineData(601, 1024)]
  [InlineData(30, 1023)]
  [InlineData(30, 16 * 1024 * 1024 + 1)]
  public void ProviderConstructor_OptionOutsideBounds_ThrowsTypedFailure(int timeoutSeconds, int maximumOutputCharacters)
  {
    var options = ValidProviderOptions();
    options.TimeoutSeconds = timeoutSeconds;
    options.MaximumOutputCharacters = maximumOutputCharacters;

    var error = Assert.Throws<BwsException>(() => new BitwardenSecretsManagerProvider(options, new UnusedRunner()));

    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
  }

  [Fact]
  public void ProviderConstructor_NonReadOnlyPurpose_ThrowsTypedFailure()
  {
    var options = ValidProviderOptions();
    options.TokenPurpose = (BwsTokenPurpose)int.MaxValue;

    var error = Assert.Throws<BwsException>(() => new BitwardenSecretsManagerProvider(options, new UnusedRunner()));

    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
  }

  [Fact]
  public void ProviderConstructor_RequiredSecretNamesUseOrdinalRules()
  {
    var accepted = ValidProviderOptions();
    accepted.RequiredSecretNames = new HashSet<string>(["Database.Password", "database.password"], StringComparer.Ordinal);
    accepted.SecretIdsByName["Database.Password"] = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
    accepted.SecretIdsByName["database.password"] = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
    var rejected = ValidProviderOptions();
    rejected.RequiredSecretNames.Add(" ");

    _ = new BitwardenSecretsManagerProvider(accepted, new UnusedRunner());
    var error = Assert.Throws<BwsException>(() => new BitwardenSecretsManagerProvider(rejected, new UnusedRunner()));

    Assert.Equal(2, accepted.RequiredSecretNames.Count);
    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
  }

  [Fact]
  public void ProviderConstructor_SecretIdMappingsRequireUniqueUuidsAndExactRequiredNames()
  {
    var invalidId = ValidProviderOptions();
    invalidId.SecretIdsByName["Key"] = "not-a-uuid";
    var duplicateIds = ValidProviderOptions();
    duplicateIds.SecretIdsByName["One"] = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
    duplicateIds.SecretIdsByName["Two"] = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA";
    var missingExactName = ValidProviderOptions();
    missingExactName.RequiredSecretNames.Add("Database.Password");
    missingExactName.SecretIdsByName["database.password"] = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";

    Assert.Equal(BwsFailureKind.InvalidConfiguration, Assert.Throws<BwsException>(() => new BitwardenSecretsManagerProvider(invalidId, new UnusedRunner())).Kind);
    Assert.Equal(BwsFailureKind.InvalidConfiguration, Assert.Throws<BwsException>(() => new BitwardenSecretsManagerProvider(duplicateIds, new UnusedRunner())).Kind);
    Assert.Equal(BwsFailureKind.InvalidConfiguration, Assert.Throws<BwsException>(() => new BitwardenSecretsManagerProvider(missingExactName, new UnusedRunner())).Kind);
  }

  [Fact]
  public async Task AcquireAsync_DerivesCanonicalIdentityAndApplicationFilename()
  {
    var root = Path.Combine(Path.GetTempPath(), $"atap-bws-path-{Guid.NewGuid():N}");
    var identity = new MutableIdentity { MachineName = "Host-One", SamAccountName = "SvcBuilder" };
    var directory = Path.Combine(root, "svcbuilder");
    var expectedPath = Path.Combine(directory, "HOST-ONE_svcbuilder_BWS_AceCommander_ReadOnly_AccessToken.xml");
    Directory.CreateDirectory(directory);
    await File.WriteAllTextAsync(expectedPath, "synthetic fixture");
    var validator = new CapturingPathValidator();
    try
    {
      var source = CreateTokenSource(ValidTokenOptions(root), identity, validator);

      var error = await Assert.ThrowsAsync<BwsException>(async () => await source.AcquireAsync());

      Assert.Equal(BwsFailureKind.TokenPathInaccessible, error.Kind);
      Assert.Equal(directory, validator.DirectoryPath);
      Assert.Equal(expectedPath, validator.TokenFilePath);
      Assert.Equal(identity.SecurityIdentifier, validator.CurrentSid);
    }
    finally
    {
      File.Delete(expectedPath);
      Directory.Delete(directory);
      Directory.Delete(root);
    }
  }

  [Theory]
  [InlineData("MachineName", "..")]
  [InlineData("SamAccountName", "bad/name")]
  [InlineData("ApplicationId", "ending.")]
  [InlineData("VaultGroupingId", "ending ")]
  [InlineData("LegacyTokenLabel", ".")]
  public async Task AcquireAsync_InvalidPathSegment_ThrowsBeforeFileAccess(string segment, string value)
  {
    var identity = new MutableIdentity();
    var options = ValidTokenOptions(Path.GetTempPath());
    switch (segment)
    {
      case "MachineName": identity.MachineName = value; break;
      case "SamAccountName": identity.SamAccountName = value; break;
      case "ApplicationId": options.ApplicationId = value; break;
      case "VaultGroupingId": options.VaultGroupingId = value; break;
      case "LegacyTokenLabel": options.LegacyTokenLabel = value; break;
      default: throw new ArgumentOutOfRangeException(nameof(segment));
    }
    var validator = new CapturingPathValidator();
    var source = CreateTokenSource(options, identity, validator);

    var error = await Assert.ThrowsAsync<BwsException>(async () => await source.AcquireAsync());

    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
    Assert.Null(validator.TokenFilePath);
  }

  [Theory]
  [InlineData(0)]
  [InlineData(16 * 1024 * 1024 + 1)]
  public async Task AcquireAsync_CredentialFileLimitOutsideBounds_ThrowsTypedFailure(int maximumCredentialFileBytes)
  {
    var options = ValidTokenOptions(Path.GetTempPath());
    options.MaximumCredentialFileBytes = maximumCredentialFileBytes;
    var source = CreateTokenSource(options, new MutableIdentity(), new CapturingPathValidator());

    var error = await Assert.ThrowsAsync<BwsException>(async () => await source.AcquireAsync());

    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
  }

  private static BitwardenSecretsManagerOptions ValidProviderOptions() => new()
  {
    ApplicationId = "AceCommander",
    ProjectId = ProjectId,
    ProjectName = "AceCommander",
    BwsExecutablePath = Path.Combine(Path.GetTempPath(), "bws.exe"),
  };

  private static WindowsBwsTokenSourceOptions ValidTokenOptions(string root) => new()
  {
    CredentialRootDirectory = root,
    ApplicationId = "AceCommander",
    VaultGroupingId = ProjectId,
    LegacyTokenLabel = "CommonCIForBitwardenReadOnly",
  };

  private static WindowsDpapiBwsReadOnlyAccessTokenSource CreateTokenSource(
    WindowsBwsTokenSourceOptions options,
    IWindowsIdentityContext identity,
    IWindowsTokenPathSecurityValidator validator) => new(
      options,
      identity,
      new BwsDpapiEnvelopeReader(new UnusedProtector()),
      new PowerShellCredentialCliXmlReader(new UnusedUnprotector()),
      validator);

  private sealed class UnusedRunner : IBwsProcessRunner
  {
    public Task<BwsProcessResult> RunAsync(IReadOnlyList<string> arguments, CancellationToken cancellationToken = default) =>
      throw new InvalidOperationException("The validation test must not invoke the process runner.");
  }

  private sealed class MutableIdentity : IWindowsIdentityContext
  {
    public string MachineName { get; set; } = "HOST01";
    public string SamAccountName { get; set; } = "svcbuilder";
    public string SecurityIdentifier { get; set; } = "S-1-5-21-1";
    public string ProgramDataDirectory { get; set; } = Path.GetTempPath();
  }

  private sealed class CapturingPathValidator : IWindowsTokenPathSecurityValidator
  {
    public string? DirectoryPath { get; private set; }
    public string? TokenFilePath { get; private set; }
    public string? CurrentSid { get; private set; }

    public void Validate(string directoryPath, string tokenFilePath, string currentSid)
    {
      DirectoryPath = directoryPath;
      TokenFilePath = tokenFilePath;
      CurrentSid = currentSid;
      throw new BwsException(BwsFailureKind.TokenPathInaccessible, "Synthetic validator stop.");
    }
  }

  private sealed class UnusedProtector : IBwsDpapiProtector
  {
    public byte[] UnprotectForCurrentUser(byte[] ciphertext, byte[] entropy) =>
      throw new InvalidOperationException("The path test must stop before DPAPI.");
  }

  private sealed class UnusedUnprotector : IDpapiUnprotector
  {
    public byte[] UnprotectForCurrentUser(byte[] ciphertext) =>
      throw new InvalidOperationException("The path test must stop before DPAPI.");
  }
}
