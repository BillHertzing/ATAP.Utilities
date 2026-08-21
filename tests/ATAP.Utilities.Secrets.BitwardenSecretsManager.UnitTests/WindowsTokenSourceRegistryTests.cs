using System.Runtime.Versioning;
using System.Security.Cryptography;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

[SupportedOSPlatform("windows")]
public sealed class WindowsTokenSourceRegistryTests
{
  [Fact]
  public async Task AcquireAsync_DisabledLegacySlotIsInvisible_WhenCanonicalSlotExists()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var expectedHash = fixture.HashToken(token);

    try
    {
      fixture.WriteEnvelope(fixture.CanonicalPath(), fixture.CurrentBinding, token);
      fixture.WriteLegacy(fixture.LegacyPath(), token);

      using var lease = await fixture.CreateSource(
        tokenSlots:
        [
          WindowsBwsTokenSlotDescriptor.LegacyCiCliXml,
          WindowsBwsTokenSlotDescriptor.ApplicationEnvelope with { Enabled = true },
        ]).AcquireAsync();

      Assert.True(fixture.LeaseMatchesHash(lease, expectedHash));
    }
    finally
    {
      CryptographicOperations.ZeroMemory(expectedHash);
      Array.Clear(token);
    }
  }

  [Fact]
  public async Task AcquireAsync_TwoEnabledExistingSlots_RejectsAsAmbiguousWithoutSensitiveValues()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var primaryPath = fixture.CanonicalPath();
    var secondaryPath = Path.Combine(fixture.CreateIdentityDirectory(), "secondary-envelope.xml");
    var secondarySlot = WindowsBwsTokenSlotDescriptor.ApplicationEnvelope with
    {
      SlotId = "secondary-envelope",
      FilenamePattern = "secondary-envelope.xml",
      Enabled = true,
    };

    try
    {
      fixture.WriteEnvelope(primaryPath, fixture.CurrentBinding, token);
      fixture.WriteEnvelope(secondaryPath, fixture.CurrentBinding, token);

      var error = await Assert.ThrowsAsync<BwsException>(
        async () => await fixture.CreateSource(
          tokenSlots:
          [
            WindowsBwsTokenSlotDescriptor.ApplicationEnvelope with { Enabled = true },
            secondarySlot,
          ]).AcquireAsync());

      Assert.Equal(BwsFailureKind.TokenCandidateAmbiguous, error.Kind);
      AssertRedacted(error, token, primaryPath, secondaryPath);
    }
    finally
    {
      Array.Clear(token);
    }
  }

  [Fact]
  public async Task AcquireAsync_CaseVariantEnabledPaths_RejectsAsAmbiguousWithoutSensitiveValues()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var upperCaseSlot = WindowsBwsTokenSlotDescriptor.ApplicationEnvelope with
    {
      SlotId = "case-variant-upper",
      FilenamePattern = "CASE-VARIANT.XML",
      Enabled = true,
    };
    var lowerCaseSlot = upperCaseSlot with
    {
      SlotId = "case-variant-lower",
      FilenamePattern = "case-variant.xml",
    };

    try
    {
      var error = await Assert.ThrowsAsync<BwsException>(
        async () => await fixture.CreateSource(tokenSlots: [upperCaseSlot, lowerCaseSlot]).AcquireAsync());

      Assert.Equal(BwsFailureKind.TokenCandidateAmbiguous, error.Kind);
      AssertRedacted(error, token, "CASE-VARIANT.XML", "case-variant.xml");
    }
    finally
    {
      Array.Clear(token);
    }
  }

  [Fact]
  public async Task AcquireAsync_UnknownSlotId_RejectsWithoutDisclosingSlotIdentifier()
  {
    using var fixture = new WindowsTokenTestFixture();
    const string unknownSlotId = "unknown-slot-id-sensitive-marker";
    var options = new WindowsBwsTokenSourceOptions
    {
      CredentialRootDirectory = fixture.RootDirectory,
      ApplicationId = WindowsTokenTestFixture.ApplicationId,
      VaultGroupingId = WindowsTokenTestFixture.VaultGroupingId,
      EnabledSlotId = unknownSlotId,
    };

    var error = await Assert.ThrowsAsync<BwsException>(
      async () => await CreateSource(fixture, options).AcquireAsync());

    Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
    AssertRedacted(error, null, unknownSlotId);
  }

  [Fact]
  public async Task AcquireAsync_DeclaredEnvelopeSlotContainingLegacyFormat_RejectsWithoutSensitiveValues()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var path = fixture.CanonicalPath();

    try
    {
      fixture.WriteLegacy(path, token);

      var error = await Assert.ThrowsAsync<BwsException>(
        async () => await fixture.CreateSource(
          tokenSlots: [WindowsBwsTokenSlotDescriptor.ApplicationEnvelope with { Enabled = true }]).AcquireAsync());

      Assert.Equal(BwsFailureKind.TokenFormatUnsupported, error.Kind);
      AssertRedacted(error, token, path);
    }
    finally
    {
      Array.Clear(token);
    }
  }

  [Fact]
  public async Task AcquireAsync_DisabledLegacyAndEnabledCanonicalSlots_CoexistWithoutAmbiguity()
  {
    using var fixture = new WindowsTokenTestFixture();
    var legacyToken = fixture.CreateSyntheticToken();
    var canonicalToken = fixture.CreateSyntheticToken();
    var expectedHash = fixture.HashToken(canonicalToken);

    try
    {
      fixture.WriteLegacy(fixture.LegacyPath(), legacyToken);
      fixture.WriteEnvelope(fixture.CanonicalPath(), fixture.CurrentBinding, canonicalToken);

      using var lease = await fixture.CreateSource(
        tokenSlots:
        [
          WindowsBwsTokenSlotDescriptor.LegacyCiCliXml,
          WindowsBwsTokenSlotDescriptor.ApplicationEnvelope with { Enabled = true },
        ]).AcquireAsync();

      Assert.True(fixture.LeaseMatchesHash(lease, expectedHash));
    }
    finally
    {
      CryptographicOperations.ZeroMemory(expectedHash);
      Array.Clear(legacyToken);
      Array.Clear(canonicalToken);
    }
  }

  [Fact]
  public async Task AcquireAsync_NonReadOnlySlot_RejectsBeforePathResolutionWithoutSensitiveValues()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var path = fixture.CanonicalPath();
    var readWriteSlot = WindowsBwsTokenSlotDescriptor.ApplicationEnvelope with
    {
      Purpose = (BwsTokenPurpose)int.MaxValue,
      Enabled = true,
    };

    try
    {
      fixture.WriteEnvelope(path, fixture.CurrentBinding, token);

      var error = await Assert.ThrowsAsync<BwsException>(
        async () => await fixture.CreateSource(tokenSlots: [readWriteSlot]).AcquireAsync());

      Assert.Equal(BwsFailureKind.InvalidConfiguration, error.Kind);
      AssertRedacted(error, token, path);
    }
    finally
    {
      Array.Clear(token);
    }
  }

  private static WindowsDpapiBwsReadOnlyAccessTokenSource CreateSource(
    WindowsTokenTestFixture fixture,
    WindowsBwsTokenSourceOptions options) =>
    new(
      options,
      fixture.CurrentIdentity,
      new BwsDpapiEnvelopeReader(new DpapiUnprotector()),
      new PowerShellCredentialCliXmlReader(new DpapiUnprotector()),
      new WindowsTokenTestFixture.AllowingSecurityValidator());

  private static void AssertRedacted(BwsException error, char[]? token, params string[] sensitiveValues)
  {
    if (token is not null) Assert.DoesNotContain(new string(token), error.Message, StringComparison.Ordinal);
    foreach (var value in sensitiveValues)
      Assert.DoesNotContain(value, error.Message, StringComparison.Ordinal);
  }
}
