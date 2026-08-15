using System.Globalization;
using System.Xml;
using System.Xml.Linq;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

public sealed class PowerShellCredentialCliXmlReader
{
  private readonly IDpapiUnprotector _unprotector;
  public PowerShellCredentialCliXmlReader(IDpapiUnprotector unprotector) { _unprotector = unprotector; }

  public char[] ReadToken(string path, string expectedCredentialUserName, int maximumBytes)
  {
    var info = new FileInfo(path);
    if (!info.Exists) throw new BwsException(BwsFailureKind.TokenFileMissing, "The DPAPI token file was not found.");
    if (info.Length is <= 0 || info.Length > maximumBytes) throw new BwsException(BwsFailureKind.TokenFormatUnsupported, "The DPAPI token file has an invalid size.");
    if ((info.Attributes & FileAttributes.ReparsePoint) != 0) throw new BwsException(BwsFailureKind.TokenPathInaccessible, "Reparse-point token files are not allowed.");

    try
    {
      using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.SequentialScan);
      var settings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = maximumBytes };
      using var reader = XmlReader.Create(stream, settings);
      var document = XDocument.Load(reader, LoadOptions.None);
      var username = FindNamedValue(document, "UserName");
      var cipherHex = FindNamedValue(document, "Password");
      if (!string.Equals(username, expectedCredentialUserName, StringComparison.Ordinal))
        throw new BwsException(BwsFailureKind.TokenIdentityMismatch, "The CLIXML credential label is not BWS_ACCESS_TOKEN.");
      if (cipherHex.Length == 0 || cipherHex.Length % 2 != 0) throw new FormatException();
      var ciphertext = Convert.FromHexString(cipherHex);
      try
      {
        var plaintext = _unprotector.UnprotectForCurrentUser(ciphertext);
        try
        {
          if (plaintext.Length == 0 || plaintext.Length % 2 != 0) throw new FormatException();
          var token = System.Text.Encoding.Unicode.GetChars(plaintext);
          if (token.Length == 0) throw new FormatException();
          return token;
        }
        finally { System.Security.Cryptography.CryptographicOperations.ZeroMemory(plaintext); }
      }
      finally { System.Security.Cryptography.CryptographicOperations.ZeroMemory(ciphertext); }
    }
    catch (BwsException) { throw; }
    catch (Exception exception) when (exception is XmlException or IOException or UnauthorizedAccessException or FormatException)
    { throw new BwsException(BwsFailureKind.TokenFormatUnsupported, "The token file is not a supported PowerShell PSCredential CLIXML document.", exception); }
  }

  private static string FindNamedValue(XDocument document, string name)
  {
    var matches = document.Descendants().Where(element =>
      (element.Name.LocalName is "S" or "SS") && string.Equals((string?)element.Attribute("N"), name, StringComparison.Ordinal)).ToArray();
    if (matches.Length != 1 || string.IsNullOrEmpty(matches[0].Value)) throw new FormatException();
    return matches[0].Value;
  }
}