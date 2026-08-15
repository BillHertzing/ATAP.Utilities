using System.Text;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

public sealed class PowerShellCredentialCliXmlReaderTests
{
  [Fact]
  public void ReadToken_DecodesPowerShellCredentialShape()
  {
    var path = WriteCliXml("BWS_ACCESS_TOKEN", "01020304");
    try
    {
      var reader = new PowerShellCredentialCliXmlReader(new FakeUnprotector("read-only-token"));
      var token = reader.ReadToken(path, "BWS_ACCESS_TOKEN", 4096);
      try { Assert.Equal("read-only-token", new string(token)); }
      finally { Array.Clear(token); }
    }
    finally { File.Delete(path); }
  }

  [Fact]
  public void ReadToken_RejectsDifferentIdentity()
  {
    var path = WriteCliXml("WrongLabel", "01020304");
    try
    {
      var reader = new PowerShellCredentialCliXmlReader(new FakeUnprotector("token"));
      var error = Assert.Throws<BwsException>(() => reader.ReadToken(path, "BWS_ACCESS_TOKEN", 4096));
      Assert.Equal(BwsFailureKind.TokenIdentityMismatch, error.Kind);
    }
    finally { File.Delete(path); }
  }

  private static string WriteCliXml(string username, string ciphertext)
  {
    var path = Path.Combine(Path.GetTempPath(), $"atap-bws-{Guid.NewGuid():N}.xml");
    File.WriteAllText(path, $"""<Objs><Obj><Props><S N="UserName">{username}</S><SS N="Password">{ciphertext}</SS></Props></Obj></Objs>""");
    return path;
  }

  private sealed class FakeUnprotector(string token) : IDpapiUnprotector
  { public byte[] UnprotectForCurrentUser(byte[] ciphertext) => Encoding.Unicode.GetBytes(token); }
}