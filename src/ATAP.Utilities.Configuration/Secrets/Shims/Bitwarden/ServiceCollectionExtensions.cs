using Microsoft.Extensions.DependencyInjection;

using ATAP.Utilities.Configuration.Secrets;

namespace ATAP.Utilities.Configuration.Secrets.Shim.Bitwarden;

/// <summary>
/// DI registration for the Bitwarden secrets shim.
/// </summary>
public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registers <see cref="BitwardenSecretsShim"/> as the active secrets provider
    /// and wires the full <see cref="IConfigurationSecrets"/> chain.
    /// </summary>
    /// <remarks>
    /// Requires <c>BW_SESSION</c> to be set in the environment (populated at login by
    /// <c>Initialize-BitwardenSession</c> in LoginScript.ps1) before any secret is requested.
    /// To add a second vault later, register an additional <c>IConfigurationSecretsShim</c>
    /// before calling this method — <c>ConfigurationSecretsShims</c> will route across all
    /// registered shims in order.
    /// </remarks>
    public static IServiceCollection AddBitwardenSecrets(this IServiceCollection services)
        => services.AddConfigurationSecrets<BitwardenSecretsShim>();
}
