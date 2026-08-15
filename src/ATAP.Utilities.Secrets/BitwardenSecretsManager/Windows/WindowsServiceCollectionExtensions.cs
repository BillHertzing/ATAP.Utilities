using System.Runtime.Versioning;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

[SupportedOSPlatform("windows")]
public static class WindowsServiceCollectionExtensions
{
  public static IServiceCollection AddWindowsDpapiBwsReadOnlyAccessTokenSource(this IServiceCollection services, WindowsBwsTokenSourceOptions options)
  {
    ArgumentNullException.ThrowIfNull(services); ArgumentNullException.ThrowIfNull(options);
    services.AddSingleton(options); services.AddSingleton<IWindowsIdentityContext, WindowsIdentityContext>();
    services.AddSingleton<DpapiUnprotector>();
    services.AddSingleton<IDpapiUnprotector>(provider => provider.GetRequiredService<DpapiUnprotector>());
    services.AddSingleton<IBwsDpapiProtector>(provider => provider.GetRequiredService<DpapiUnprotector>());
    services.AddSingleton<PowerShellCredentialCliXmlReader>(); services.AddSingleton<BwsDpapiEnvelopeReader>();
    services.TryAddSingleton<IWindowsTokenPathSecurityValidator, StrictWindowsTokenPathSecurityValidator>();
    services.AddSingleton<IBwsReadOnlyAccessTokenSource, WindowsDpapiBwsReadOnlyAccessTokenSource>(); return services;
  }
}