using Microsoft.Extensions.DependencyInjection;

using ATAP.Utilities.Configuration.Secrets.Shims;

namespace ATAP.Utilities.Configuration.Secrets;

/// <summary>
/// DI registration helpers for the IConfigurationSecrets chain.
/// </summary>
public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registers the complete IConfigurationSecrets chain backed by the specified shim.
    /// </summary>
    /// <typeparam name="TShim">
    /// The <see cref="IConfigurationSecretsShim"/> implementation to use as the
    /// secrets back-end (e.g. <c>BitwardenSecretsShim</c>).
    /// </typeparam>
    /// <remarks>
    /// Registers two singletons:
    /// <list type="number">
    ///   <item><c>IConfigurationSecretsShim → TShim</c> — the concrete back-end.</item>
    ///   <item><c>IConfigurationSecrets → ConfigurationSecretsShims</c> — the shim router;
    ///         resolves all registered <c>IConfigurationSecretsShim</c> instances via DI
    ///         and returns the first non-null result in registration order.</item>
    /// </list>
    /// To add a second vault later, register an additional
    /// <c>IConfigurationSecretsShim</c> before calling this method.
    /// </remarks>
    public static IServiceCollection AddConfigurationSecrets<TShim>(
        this IServiceCollection services)
        where TShim : class, IConfigurationSecretsShim
    {
        services.AddSingleton<IConfigurationSecretsShim, TShim>();
        services.AddSingleton<IConfigurationSecrets, ConfigurationSecretsShims>();
        return services;
    }
}
