using System.Security.Cryptography;
using System.Text;
using System.Xml;
using System.Xml.Linq;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public sealed class BwsDpapiEnvelopeReader
{
  public const string RootName = "AtapBwsDpapiEnvelope";
  private const string FormatVersion = "1";
  private const string Provider = "BitwardenSecretsManager";
  private readonly IBwsDpapiProtector _protector;

  public BwsDpapiEnvelopeReader(IBwsDpapiProtector protector) => _protector = protector;

  public char[] ReadToken(string path, BwsTokenBinding expected, int maximumBytes)
  {
    var info = new FileInfo(path);
    if (!info.Exists || info.Length is <= 0 || info.Length > maximumBytes || (info.Attributes & FileAttributes.ReparsePoint) != 0)
      throw new BwsException(BwsFailureKind.TokenPathInaccessible, "The BWS DPAPI envelope path is invalid.");
    try
    {
      using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.SequentialScan);
      var settings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = maximumBytes };
      using var xml = XmlReader.Create(stream, settings);
      var root = XDocument.Load(xml, LoadOptions.None).Root ?? throw new FormatException();
      var allowedElements = new HashSet<string>(["formatVersion", "purpose", "host", "sid", "samAccountName", "applicationId", "provider", "vaultGroupingId", "ciphertext"], StringComparer.Ordinal);
      if (root.Name != RootName || root.HasAttributes || root.Elements().Count() != allowedElements.Count ||
          root.Elements().Any(element => element.Name.NamespaceName.Length != 0 || !allowedElements.Contains(element.Name.LocalName) || element.HasAttributes || element.HasElements)) throw new FormatException();
      var version = One(root, "formatVersion");
      var purpose = One(root, "purpose");
      var host = One(root, "host");
      var sid = One(root, "sid");
      var sam = One(root, "samAccountName");
      var applicationId = One(root, "applicationId");
      var provider = One(root, "provider");
      var grouping = One(root, "vaultGroupingId");
      if (version != FormatVersion || purpose != "ReadOnly" || provider != Provider ||
          host != expected.Host || sid != expected.Sid || sam != expected.SamAccountName ||
          applicationId != expected.ApplicationId || grouping != expected.VaultGroupingId)
        throw new BwsException(BwsFailureKind.TokenIdentityMismatch, "The BWS token envelope is not bound to the current identity, application, and vault grouping.");
      var encodedCiphertext = One(root, "ciphertext");
      var ciphertext = Convert.FromBase64String(encodedCiphertext);
      if (!string.Equals(Convert.ToBase64String(ciphertext), encodedCiphertext, StringComparison.Ordinal)) throw new FormatException();
      var entropy = CreateEntropy(expected);
      try
      {
        var plaintext = _protector.UnprotectForCurrentUser(ciphertext, entropy);
        try { return DecodeInner(plaintext, expected); }
        finally { CryptographicOperations.ZeroMemory(plaintext); }
      }
      finally { CryptographicOperations.ZeroMemory(ciphertext); CryptographicOperations.ZeroMemory(entropy); }
    }
    catch (BwsException) { throw; }
    catch (Exception exception) when (exception is XmlException or IOException or UnauthorizedAccessException or FormatException)
    { throw new BwsException(BwsFailureKind.TokenFormatUnsupported, "The token file is not a supported ATAP BWS DPAPI envelope.", exception); }
  }

  public static byte[] CreateEntropy(BwsTokenBinding binding)
  {
    using var stream = new MemoryStream();
    using var writer = new BinaryWriter(stream, new UTF8Encoding(false, true), leaveOpen: true);
    foreach (var value in new[] { "ATAP.BWS.DPAPI.ENVELOPE", FormatVersion, binding.Host, binding.Sid, binding.ApplicationId, Provider, binding.VaultGroupingId, "ReadOnly" }) writer.Write(value);
    writer.Flush(); return stream.ToArray();
  }

  private static char[] DecodeInner(byte[] bytes, BwsTokenBinding expected)
  {
    using var stream = new MemoryStream(bytes, writable: false);
    using var reader = new BinaryReader(stream, new UTF8Encoding(false, true));
    if (reader.ReadString() != "ATAP.BWS.TOKEN" || reader.ReadString() != FormatVersion || reader.ReadString() != "ReadOnly" ||
        reader.ReadString() != expected.Host || reader.ReadString() != expected.Sid || reader.ReadString() != expected.SamAccountName ||
        reader.ReadString() != expected.ApplicationId || reader.ReadString() != Provider || reader.ReadString() != expected.VaultGroupingId) throw new FormatException();
    var length = reader.ReadInt32();
    if (length <= 0 || length > 1024 * 1024 || length != stream.Length - stream.Position) throw new FormatException();
    var tokenBytes = reader.ReadBytes(length);
    try { return new UTF8Encoding(false, true).GetChars(tokenBytes); }
    finally { CryptographicOperations.ZeroMemory(tokenBytes); }
  }

  private static string One(XElement root, string name)
  {
    var values = root.Elements().Where(x => x.Name.LocalName == name).ToArray();
    if (values.Length != 1 || string.IsNullOrEmpty(values[0].Value)) throw new FormatException();
    return values[0].Value;
  }
}

public sealed record BwsTokenBinding(string Host, string Sid, string SamAccountName, string ApplicationId, string VaultGroupingId);