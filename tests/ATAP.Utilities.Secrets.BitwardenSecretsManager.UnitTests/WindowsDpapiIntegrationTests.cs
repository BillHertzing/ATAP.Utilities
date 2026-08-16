using System.Runtime.Versioning;
using System.Security.Cryptography;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

[SupportedOSPlatform("windows")]
public sealed class WindowsDpapiIntegrationTests
{
  [Fact]
  public async Task AcquireAsync_CurrentIdentityDpapiEnvelope_RoundTripsSyntheticValueAndCleansUp()
  {
    var fixture = new WindowsTokenTestFixture();
    var root = fixture.RootDirectory;
    var token = fixture.CreateSyntheticToken();
    var expectedHash = fixture.HashToken(token);

    try
    {
      var path = fixture.CanonicalPath();
      fixture.WriteEnvelope(path, fixture.CurrentBinding, token);

      using var lease = await fixture.CreateSource().AcquireAsync();

      Assert.True(fixture.LeaseMatchesHash(lease, expectedHash));
      Assert.False(fixture.FileContainsToken(path, token));
    }
    finally
    {
      CryptographicOperations.ZeroMemory(expectedHash);
      Array.Clear(token);
      fixture.Dispose();
    }

    Assert.False(Directory.Exists(root));
  }
}
