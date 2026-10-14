using System.Diagnostics;
using System.Runtime.Versioning;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Xml.Linq;
using ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.UnitTests;

[SupportedOSPlatform("windows")]
internal sealed class WindowsTokenTestFixture : IDisposable
{
  internal const string ApplicationId = "AceCommander";
  internal const string VaultGroupingId = "11111111-1111-1111-1111-111111111111";
  private bool _disposed;

  public WindowsTokenTestFixture()
  {
    if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException("Windows DPAPI tests require Windows.");
    RootDirectory = Path.Combine(Path.GetTempPath(), "atap-bws-dpapi-tests", Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(RootDirectory);
    CurrentIdentity = new TestWindowsIdentity(
      Environment.MachineName.ToUpperInvariant(),
      WindowsIdentity.GetCurrent().Name.Split('\\').Last().ToLowerInvariant(),
      WindowsIdentity.GetCurrent().User?.Value ?? throw new InvalidOperationException("The effective Windows identity has no SID."),
      Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData));
  }

  public string RootDirectory { get; }
  public TestWindowsIdentity CurrentIdentity { get; }

  public BwsTokenBinding CurrentBinding => BindingFor(CurrentIdentity);

  public string CreateIdentityDirectory(IWindowsIdentityContext? identity = null)
  {
    identity ??= CurrentIdentity;
    var directory = Path.Combine(RootDirectory, identity.SamAccountName.ToLowerInvariant());
    Directory.CreateDirectory(directory);
    return directory;
  }

  public string CanonicalPath(IWindowsIdentityContext? identity = null)
  {
    identity ??= CurrentIdentity;
    return Path.Combine(
      CreateIdentityDirectory(identity),
      $"{identity.MachineName.ToUpperInvariant()}_{identity.SamAccountName.ToLowerInvariant()}_BWS_{ApplicationId}_ReadOnly_AccessToken.xml");
  }

  public string LegacyPath(IWindowsIdentityContext? identity = null)
  {
    identity ??= CurrentIdentity;
    return Path.Combine(
      CreateIdentityDirectory(identity),
      $"{identity.MachineName.ToUpperInvariant()}_{identity.SamAccountName.ToLowerInvariant()}_BWS_CommonCIForBitwardenReadOnly_AccessToken.xml");
  }

  public static BwsTokenBinding BindingFor(IWindowsIdentityContext identity) =>
    new(
      identity.MachineName.ToUpperInvariant(),
      identity.SecurityIdentifier,
      identity.SamAccountName.ToLowerInvariant(),
      ApplicationId,
      VaultGroupingId);

  public char[] CreateSyntheticToken()
  {
    var random = RandomNumberGenerator.GetBytes(48);
    try
    {
      var token = new char[random.Length];
      for (var index = 0; index < random.Length; index++)
        token[index] = (char)('!' + random[index] % 90);
      return token;
    }
    finally
    {
      CryptographicOperations.ZeroMemory(random);
    }
  }

  public byte[] HashToken(char[] token)
  {
    var bytes = Encoding.UTF8.GetBytes(token);
    try { return SHA256.HashData(bytes); }
    finally { CryptographicOperations.ZeroMemory(bytes); }
  }

  public bool LeaseMatchesHash(IBwsAccessTokenLease lease, ReadOnlySpan<byte> expectedHash)
  {
    var startInfo = new ProcessStartInfo { UseShellExecute = false };
    try
    {
      lease.ApplyTo(startInfo);
      var observed = startInfo.Environment["BWS_ACCESS_TOKEN"];
      if (observed is null) return false;
      var observedBytes = Encoding.UTF8.GetBytes(observed);
      try
      {
        var observedHash = SHA256.HashData(observedBytes);
        try { return CryptographicOperations.FixedTimeEquals(expectedHash, observedHash); }
        finally { CryptographicOperations.ZeroMemory(observedHash); }
      }
      finally { CryptographicOperations.ZeroMemory(observedBytes); }
    }
    finally
    {
      startInfo.Environment.Remove("BWS_ACCESS_TOKEN");
    }
  }

  public bool FileContainsToken(string path, char[] token)
  {
    var fileBytes = File.ReadAllBytes(path);
    var tokenBytes = Encoding.UTF8.GetBytes(token);
    try { return fileBytes.AsSpan().IndexOf(tokenBytes) >= 0; }
    finally
    {
      CryptographicOperations.ZeroMemory(fileBytes);
      CryptographicOperations.ZeroMemory(tokenBytes);
    }
  }

  public void WriteEnvelope(
    string path,
    BwsTokenBinding protectedBinding,
    char[] token,
    BwsTokenBinding? outerBinding = null,
    string rootName = BwsDpapiEnvelopeReader.RootName,
    string version = "1",
    string purpose = "ReadOnly",
    byte[]? ciphertextOverride = null)
  {
    outerBinding ??= protectedBinding;
    var inner = BuildInner(protectedBinding, token);
    var entropy = BwsDpapiEnvelopeReader.CreateEntropy(protectedBinding);
    byte[] ciphertext;
    try
    {
      ciphertext = ciphertextOverride?.ToArray()
        ?? ProtectedData.Protect(inner, entropy, DataProtectionScope.CurrentUser);
    }
    finally
    {
      CryptographicOperations.ZeroMemory(inner);
      CryptographicOperations.ZeroMemory(entropy);
    }

    try
    {
      new XDocument(
        new XElement(
          rootName,
          new XElement("formatVersion", version),
          new XElement("purpose", purpose),
          new XElement("host", outerBinding.Host),
          new XElement("sid", outerBinding.Sid),
          new XElement("samAccountName", outerBinding.SamAccountName),
          new XElement("applicationId", outerBinding.ApplicationId),
          new XElement("provider", "BitwardenSecretsManager"),
          new XElement("vaultGroupingId", outerBinding.VaultGroupingId),
          new XElement("ciphertext", Convert.ToBase64String(ciphertext))))
        .Save(path, SaveOptions.DisableFormatting);
    }
    finally
    {
      CryptographicOperations.ZeroMemory(ciphertext);
    }
  }

  public void WriteLegacy(string path, char[] token)
  {
    var plaintext = Encoding.Unicode.GetBytes(token);
    byte[] ciphertext;
    try { ciphertext = ProtectedData.Protect(plaintext, null, DataProtectionScope.CurrentUser); }
    finally { CryptographicOperations.ZeroMemory(plaintext); }

    try
    {
      new XDocument(
        new XElement(
          "Objs",
          new XElement(
            "Obj",
            new XElement(
              "Props",
              new XElement("S", new XAttribute("N", "UserName"), "BWS_ACCESS_TOKEN"),
              new XElement("SS", new XAttribute("N", "Password"), Convert.ToHexString(ciphertext))))))
        .Save(path, SaveOptions.DisableFormatting);
    }
    finally
    {
      CryptographicOperations.ZeroMemory(ciphertext);
    }
  }

  public WindowsDpapiBwsReadOnlyAccessTokenSource CreateSource(
    IWindowsIdentityContext? identity = null,
    IWindowsTokenPathSecurityValidator? validator = null,
    bool allowLegacy = false,
    IBwsDpapiProtector? protector = null,
    IList<WindowsBwsTokenSlotDescriptor>? tokenSlots = null)
  {
    identity ??= CurrentIdentity;
    var options = new WindowsBwsTokenSourceOptions
    {
      CredentialRootDirectory = RootDirectory,
      ApplicationId = ApplicationId,
      VaultGroupingId = VaultGroupingId,
      AllowLegacyPowerShellCliXml = allowLegacy,
    };
    if (tokenSlots is not null) options.TokenSlots = tokenSlots;

    return new WindowsDpapiBwsReadOnlyAccessTokenSource(
      options,
      identity,
      new BwsDpapiEnvelopeReader(protector ?? new DpapiUnprotector()),
      new PowerShellCredentialCliXmlReader(new DpapiUnprotector()),
      validator ?? new AllowingSecurityValidator());
  }

  public void Dispose()
  {
    if (_disposed) return;
    _disposed = true;
    if (Directory.Exists(RootDirectory)) Directory.Delete(RootDirectory, recursive: true);
  }

  private static byte[] BuildInner(BwsTokenBinding binding, char[] token)
  {
    using var stream = new MemoryStream();
    using var writer = new BinaryWriter(stream, new UTF8Encoding(false, true), leaveOpen: true);
    foreach (var value in new[]
      {
        "ATAP.BWS.TOKEN",
        "1",
        "ReadOnly",
        binding.Host,
        binding.Sid,
        binding.SamAccountName,
        binding.ApplicationId,
        "BitwardenSecretsManager",
        binding.VaultGroupingId,
      })
      writer.Write(value);

    var tokenBytes = Encoding.UTF8.GetBytes(token);
    try
    {
      writer.Write(tokenBytes.Length);
      writer.Write(tokenBytes);
      writer.Flush();
      return stream.ToArray();
    }
    finally
    {
      CryptographicOperations.ZeroMemory(tokenBytes);
    }
  }

  internal sealed record TestWindowsIdentity(
    string MachineName,
    string SamAccountName,
    string SecurityIdentifier,
    string ProgramDataDirectory) : IWindowsIdentityContext;

  internal sealed class AllowingSecurityValidator : IWindowsTokenPathSecurityValidator
  {
    public int Calls { get; private set; }

    public void Validate(string directoryPath, string tokenFilePath, string currentSid) => Calls++;
  }

  internal sealed class RejectingSecurityValidator : IWindowsTokenPathSecurityValidator
  {
    public void Validate(string directoryPath, string tokenFilePath, string currentSid) =>
      throw new BwsException(BwsFailureKind.TokenPathInaccessible, "Synthetic ACL abstraction rejected the path.");
  }

  internal sealed class ThrowIfCalledProtector : IBwsDpapiProtector
  {
    public int Calls { get; private set; }

    public byte[] UnprotectForCurrentUser(byte[] ciphertext, byte[] entropy)
    {
      Calls++;
      throw new InvalidOperationException("Decryption must not run for a pre-decryption rejection.");
    }
  }
}
