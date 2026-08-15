namespace ATAP.Utilities.Secrets;

using System;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

[System.Obsolete(BitwardenPasswordManagerCompatibility.Message, DiagnosticId = BitwardenPasswordManagerCompatibility.DiagnosticId, UrlFormat = BitwardenPasswordManagerCompatibility.UrlFormat)]
public static class ServiceCollectionExtensions
{
  public static IServiceCollection AddBitwardenSecrets(
      this IServiceCollection services,
      Action<BitwardenSecretsOptions>? configure = null)
  {
    var options = new BitwardenSecretsOptions();
    configure?.Invoke(options);
    services.AddSingleton<ISecretsAbstract>(new BitwardenSecretsShim(options));
    return services;
  }
}
