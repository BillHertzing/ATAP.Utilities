using System.Runtime.Versioning;
using System.Security.Cryptography;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

[SupportedOSPlatform("windows")]
public sealed class WindowsTokenSourceNegativeFixtureTests
{
  [Fact]
  public async Task AcquireAsync_DifferentEffectiveSid_RejectsBeforeDecryption()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var protector = new WindowsTokenTestFixture.ThrowIfCalledProtector();
    var differentIdentity = fixture.CurrentIdentity with
    {
      SecurityIdentifier = $"{fixture.CurrentIdentity.SecurityIdentifier}-999",
    };

    try
    {
      fixture.WriteEnvelope(fixture.CanonicalPath(differentIdentity), fixture.CurrentBinding, token);

      var error = await Assert.ThrowsAsync<BwsException>(
        async () => await fixture.CreateSource(differentIdentity, protector: protector).AcquireAsync());

      Assert.Equal(BwsFailureKind.TokenIdentityMismatch, error.Kind);
      Assert.Equal(0, protector.Calls);
    }
    finally
    {
      Array.Clear(token);
    }
  }

  [Theory]
  [InlineData("host")]
  [InlineData("purpose")]
  public void ReadToken_WrongHostOrPurpose_RejectsBeforeDecryption(string mismatch)
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var protector = new WindowsTokenTestFixture.ThrowIfCalledProtector();
    var outerBinding = mismatch == "host"
      ? fixture.CurrentBinding with { Host = $"{fixture.CurrentBinding.Host}-OTHER" }
      : fixture.CurrentBinding;
    var purpose = mismatch == "purpose" ? "ReadWrite" : "ReadOnly";

    try
    {
      var path = fixture.CanonicalPath();
      fixture.WriteEnvelope(path, fixture.CurrentBinding, token, outerBinding, purpose: purpose);

      var error = Assert.Throws<BwsException>(
        () => new BwsDpapiEnvelopeReader(protector).ReadToken(path, fixture.CurrentBinding, 1024 * 1024));

      Assert.Equal(BwsFailureKind.TokenIdentityMismatch, error.Kind);
      Assert.Equal(0, protector.Calls);
    }
    finally
    {
      Array.Clear(token);
    }
  }

  [Fact]
  public void ReadToken_CorruptCiphertext_ReturnsTypedFailureWithoutValue()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var corruptCiphertext = RandomNumberGenerator.GetBytes(96);

    try
    {
      var path = fixture.CanonicalPath();
      fixture.WriteEnvelope(path, fixture.CurrentBinding, token, ciphertextOverride: corruptCiphertext);

      var error = Assert.Throws<BwsException>(
        () => new BwsDpapiEnvelopeReader(new DpapiUnprotector()).ReadToken(path, fixture.CurrentBinding, 1024 * 1024));

      Assert.Equal(BwsFailureKind.TokenCiphertextCorrupt, error.Kind);
      Assert.False(fixture.FileContainsToken(path, token));
    }
    finally
    {
      CryptographicOperations.ZeroMemory(corruptCiphertext);
      Array.Clear(token);
    }
  }

  [Fact]
  public async Task AcquireAsync_AbsentFile_ReturnsTypedFailure()
  {
    using var fixture = new WindowsTokenTestFixture();
    fixture.CreateIdentityDirectory();

    var error = await Assert.ThrowsAsync<BwsException>(
      async () => await fixture.CreateSource().AcquireAsync());

    Assert.Equal(BwsFailureKind.TokenFileMissing, error.Kind);
  }

  [Fact]
  public async Task AcquireAsync_RejectingAclAbstraction_StopsBeforeFileParsing()
  {
    using var fixture = new WindowsTokenTestFixture();
    File.WriteAllText(fixture.CanonicalPath(), "<UnsupportedEnvelope />");
    var protector = new WindowsTokenTestFixture.ThrowIfCalledProtector();

    var error = await Assert.ThrowsAsync<BwsException>(
      async () => await fixture.CreateSource(
        validator: new WindowsTokenTestFixture.RejectingSecurityValidator(),
        protector: protector).AcquireAsync());

    Assert.Equal(BwsFailureKind.TokenPathInaccessible, error.Kind);
    Assert.Equal(0, protector.Calls);
  }

  [Fact]
  public async Task AcquireAsync_LegacyFileDisabled_ReturnsUnsupportedWithoutDecryption()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();

    try
    {
      fixture.WriteLegacy(fixture.LegacyPath(), token);

      var error = await Assert.ThrowsAsync<BwsException>(
        async () => await fixture.CreateSource(
          allowLegacy: false,
          tokenSlots: [WindowsBwsTokenSlotDescriptor.LegacyCiCliXml with { Enabled = true }]).AcquireAsync());

      Assert.Equal(BwsFailureKind.TokenFormatUnsupported, error.Kind);
    }
    finally
    {
      Array.Clear(token);
    }
  }

  [Fact]
  public async Task AcquireAsync_LegacyFileEnabled_RoundTripsSyntheticValue()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var expectedHash = fixture.HashToken(token);

    try
    {
      var path = fixture.LegacyPath();
      fixture.WriteLegacy(path, token);

      using var lease = await fixture.CreateSource(
        allowLegacy: true,
        tokenSlots: [WindowsBwsTokenSlotDescriptor.LegacyCiCliXml with { Enabled = true }]).AcquireAsync();

      Assert.True(fixture.LeaseMatchesHash(lease, expectedHash));
      Assert.False(fixture.FileContainsToken(path, token));
    }
    finally
    {
      CryptographicOperations.ZeroMemory(expectedHash);
      Array.Clear(token);
    }
  }

  [Fact]
  public async Task AcquireAsync_UnsupportedMarker_ReturnsTypedFailure()
  {
    using var fixture = new WindowsTokenTestFixture();
    File.WriteAllText(fixture.CanonicalPath(), "<UnsupportedEnvelope />");

    var error = await Assert.ThrowsAsync<BwsException>(
      async () => await fixture.CreateSource().AcquireAsync());

    Assert.Equal(BwsFailureKind.TokenFormatUnsupported, error.Kind);
  }

  [Fact]
  public void ReadToken_UnsupportedVersion_ReturnsTypedFailureBeforeDecryption()
  {
    using var fixture = new WindowsTokenTestFixture();
    var token = fixture.CreateSyntheticToken();
    var protector = new WindowsTokenTestFixture.ThrowIfCalledProtector();

    try
    {
      var path = fixture.CanonicalPath();
      fixture.WriteEnvelope(path, fixture.CurrentBinding, token, version: "2");

      var error = Assert.Throws<BwsException>(
        () => new BwsDpapiEnvelopeReader(protector).ReadToken(path, fixture.CurrentBinding, 1024 * 1024));

      Assert.Equal(BwsFailureKind.TokenFormatUnsupported, error.Kind);
      Assert.Equal(0, protector.Calls);
    }
    finally
    {
      Array.Clear(token);
    }
  }
}
