namespace ATAP.Utilities.Secrets;

using System;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;

[System.Obsolete(BitwardenPasswordManagerCompatibility.Message, DiagnosticId = BitwardenPasswordManagerCompatibility.DiagnosticId, UrlFormat = BitwardenPasswordManagerCompatibility.UrlFormat)]
public static class ConfigurationBuilderExtensions
{
  public static IConfigurationBuilder AddBitwardenSecrets(
      this IConfigurationBuilder builder,
      IEnumerable<SecretMapping> mappings,
      Action<BitwardenSecretsOptions>? configure = null)
  {
    var options = new BitwardenSecretsOptions();
    configure?.Invoke(options);
    return builder.Add(new BitwardenConfigurationSource(options, mappings));
  }
}
