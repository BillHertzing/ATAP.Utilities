namespace ATAP.Utilities.Secrets;

using System;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

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
