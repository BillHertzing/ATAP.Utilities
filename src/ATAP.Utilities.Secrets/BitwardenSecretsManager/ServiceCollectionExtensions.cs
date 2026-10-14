using Microsoft.Extensions.DependencyInjection;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager;

public static class ServiceCollectionExtensions
{
  public static IServiceCollection AddBitwardenSecretsManager(this IServiceCollection services, BitwardenSecretsManagerOptions options)
  {
    ArgumentNullException.ThrowIfNull(services); ArgumentNullException.ThrowIfNull(options); options.Validate();
    services.AddSingleton(options);
    services.AddSingleton<IBwsExecutableTrustVerifier, BwsExecutableTrustVerifier>();
    services.AddSingleton<IBwsProcessRunner, BwsProcessRunner>();
    services.AddSingleton<BitwardenSecretsManagerProvider>();
    services.AddSingleton<BitwardenSecretsManagerConfigurationLoader>();
    services.AddSingleton<ISecretsAbstract>(provider => provider.GetRequiredService<BitwardenSecretsManagerProvider>());
    return services;
  }
}