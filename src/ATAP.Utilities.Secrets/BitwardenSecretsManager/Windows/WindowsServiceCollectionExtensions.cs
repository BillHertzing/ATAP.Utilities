using System.Runtime.Versioning;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace ATAP.Utilities.Secrets.BitwardenSecretsManager.Windows;

[SupportedOSPlatform("windows")]
public static class WindowsServiceCollectionExtensions
{
  public static IServiceCollection AddWindowsDpapiBwsReadOnlyAccessTokenSource(
    this IServiceCollection services,
    IConfiguration configuration,
    string sectionName = WindowsBwsTokenSourceOptions.DefaultConfigurationSectionName)
  {
    ArgumentNullException.ThrowIfNull(configuration);
    if (string.IsNullOrWhiteSpace(sectionName))
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "The BWS token-source configuration section is required.");

    var section = configuration.GetSection(sectionName);
    var enabledSlotId = section["EnabledSlotId"];
    if (string.IsNullOrWhiteSpace(enabledSlotId))
      throw new BwsException(BwsFailureKind.InvalidConfiguration, "The BWS token-source configuration or enabled slot id is missing.");

    var options = new WindowsBwsTokenSourceOptions
    {
      CredentialRootDirectory = section["CredentialRootDirectory"],
      EnabledSlotId = enabledSlotId,
      LegacyTokenLabel = section["LegacyTokenLabel"] ?? "CommonCIForBitwardenReadOnly",
    };
    if (bool.TryParse(section["AllowLegacyPowerShellCliXml"], out var allowLegacy)) options.AllowLegacyPowerShellCliXml = allowLegacy;
    if (int.TryParse(section["MaximumCredentialFileBytes"], out var maximumCredentialFileBytes)) options.MaximumCredentialFileBytes = maximumCredentialFileBytes;

    return services.AddWindowsDpapiBwsReadOnlyAccessTokenSource(options);
  }
  public static IServiceCollection AddWindowsDpapiBwsReadOnlyAccessTokenSource(this IServiceCollection services, WindowsBwsTokenSourceOptions options)
  {
    ArgumentNullException.ThrowIfNull(services); ArgumentNullException.ThrowIfNull(options); options.ValidateStartupConfiguration();
    services.AddSingleton(options); services.AddSingleton<IWindowsIdentityContext, WindowsIdentityContext>();
    services.AddSingleton<DpapiUnprotector>();
    services.AddSingleton<IDpapiUnprotector>(provider => provider.GetRequiredService<DpapiUnprotector>());
    services.AddSingleton<IBwsDpapiProtector>(provider => provider.GetRequiredService<DpapiUnprotector>());
    services.AddSingleton<PowerShellCredentialCliXmlReader>(); services.AddSingleton<BwsDpapiEnvelopeReader>();
    services.TryAddSingleton<IWindowsTokenPathSecurityValidator, StrictWindowsTokenPathSecurityValidator>();
    services.AddSingleton<IBwsReadOnlyAccessTokenSource, WindowsDpapiBwsReadOnlyAccessTokenSource>(); return services;
  }
}