using System;
using System.Linq;
using System.Security.Cryptography;
using System.Security.Cryptography.Xml;
using System.Xml;
using ServiceStack.OrmLite.SqlServer;
using Xunit;

namespace ATAP.Utilities.PackageGraph.Tests;

public sealed class PackageSecurityCompatibilityTests
{
  [Fact]
  public void SqlServerDataProvider_CreatesMicrosoftDataConnectionWithoutOpeningIt()
  {
    var provider = SqlServer2022OrmLiteDialectProvider.Instance;
    var providerAssembly = provider.GetType().Assembly;
    var referencedAssemblies = providerAssembly.GetReferencedAssemblies()
      .Select(assemblyName => assemblyName.Name)
      .ToArray();

    Assert.Contains("Microsoft.Data.SqlClient", referencedAssemblies, StringComparer.Ordinal);
    Assert.DoesNotContain("System.Data.SqlClient", referencedAssemblies, StringComparer.Ordinal);

    using var connection = provider.CreateConnection(
      "Server=(local);Database=NotOpened;Integrated Security=true;TrustServerCertificate=true",
      new System.Collections.Generic.Dictionary<string, string>());

    Assert.Equal("Microsoft.Data.SqlClient.SqlConnection", connection.GetType().FullName);
    Assert.Equal(System.Data.ConnectionState.Closed, connection.State);
  }

  [Fact]
  public void SignedXml_SignAndVerify_RoundTripsInMemory()
  {
    var document = LoadDocument("<root><value>signed payload</value></root>");
    using var signingKey = RSA.Create(2048);
    var signer = new SignedXml(document)
    {
      SigningKey = signingKey,
    };
    var reference = new Reference(string.Empty);
    reference.AddTransform(new XmlDsigEnvelopedSignatureTransform());
    signer.AddReference(reference);
    signer.ComputeSignature();
    document.DocumentElement!.AppendChild(document.ImportNode(signer.GetXml(), deep: true));

    var signatureElement = (XmlElement?)document.GetElementsByTagName(
      "Signature",
      SignedXml.XmlDsigNamespaceUrl)[0];
    Assert.NotNull(signatureElement);

    var verifier = new SignedXml(document);
    verifier.LoadXml(signatureElement!);

    Assert.True(verifier.CheckSignature(signingKey));
  }

  [Fact]
  public void EncryptedXml_EncryptAndDecrypt_RoundTripsInMemory()
  {
    const string expectedValue = "encrypted payload";
    var document = LoadDocument($"<root><secret>{expectedValue}</secret></root>");
    var secretElement = (XmlElement?)document.DocumentElement?.SelectSingleNode("secret");
    Assert.NotNull(secretElement);

    using var encryptionKey = Aes.Create();
    encryptionKey.KeySize = 256;
    var encryptedXml = new EncryptedXml();
    var cipherText = encryptedXml.EncryptData(secretElement!, encryptionKey, content: false);
    var encryptedData = new EncryptedData
    {
      Type = EncryptedXml.XmlEncElementUrl,
      EncryptionMethod = new EncryptionMethod(EncryptedXml.XmlEncAES256Url),
      CipherData = new CipherData(cipherText),
    };
    EncryptedXml.ReplaceElement(secretElement!, encryptedData, content: false);

    var encryptedElement = (XmlElement?)document.GetElementsByTagName(
      "EncryptedData",
      EncryptedXml.XmlEncNamespaceUrl)[0];
    Assert.NotNull(encryptedElement);
    var parsedEncryptedData = new EncryptedData();
    parsedEncryptedData.LoadXml(encryptedElement!);
    var plainText = encryptedXml.DecryptData(parsedEncryptedData, encryptionKey);
    encryptedXml.ReplaceData(encryptedElement!, plainText);

    Assert.Equal(expectedValue, document.DocumentElement?.SelectSingleNode("secret")?.InnerText);
  }

  private static XmlDocument LoadDocument(string xml)
  {
    var document = new XmlDocument
    {
      PreserveWhitespace = true,
    };
    document.LoadXml(xml);
    return document;
  }
}
