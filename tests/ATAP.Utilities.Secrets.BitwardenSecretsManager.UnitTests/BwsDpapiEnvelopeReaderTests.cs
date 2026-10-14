using System.Text;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

public sealed class BwsDpapiEnvelopeReaderTests
{
  [Fact]
  public void ReadToken_ValidatesOuterAndInnerBinding()
  {
    var binding = new BwsTokenBinding("HOST01", "S-1-5-21-1", "svcbuilder", "AceCommander", "11111111-1111-1111-1111-111111111111");
    var inner = Inner(binding, "read-only-token");
    var path = Path.Combine(Path.GetTempPath(), $"atap-bws-envelope-{Guid.NewGuid():N}.xml");
    File.WriteAllText(path, $"""<AtapBwsDpapiEnvelope><formatVersion>1</formatVersion><purpose>ReadOnly</purpose><host>{binding.Host}</host><sid>{binding.Sid}</sid><samAccountName>{binding.SamAccountName}</samAccountName><applicationId>{binding.ApplicationId}</applicationId><provider>BitwardenSecretsManager</provider><vaultGroupingId>{binding.VaultGroupingId}</vaultGroupingId><ciphertext>{Convert.ToBase64String([1,2,3])}</ciphertext></AtapBwsDpapiEnvelope>""");
    try
    {
      var token = new BwsDpapiEnvelopeReader(new FakeProtector(inner)).ReadToken(path, binding, 8192);
      try { Assert.Equal("read-only-token", new string(token)); } finally { Array.Clear(token); }
    }
    finally { File.Delete(path); Array.Clear(inner); }
  }

  private static byte[] Inner(BwsTokenBinding binding, string token)
  {
    using var stream = new MemoryStream(); using var writer = new BinaryWriter(stream, new UTF8Encoding(false, true), leaveOpen: true);
    foreach (var value in new[] { "ATAP.BWS.TOKEN", "1", "ReadOnly", binding.Host, binding.Sid, binding.SamAccountName, binding.ApplicationId, "BitwardenSecretsManager", binding.VaultGroupingId }) writer.Write(value);
    var bytes = Encoding.UTF8.GetBytes(token); writer.Write(bytes.Length); writer.Write(bytes); writer.Flush(); Array.Clear(bytes); return stream.ToArray();
  }
  private sealed class FakeProtector(byte[] plaintext) : IBwsDpapiProtector
  { public byte[] UnprotectForCurrentUser(byte[] ciphertext, byte[] entropy) => plaintext.ToArray(); }
}