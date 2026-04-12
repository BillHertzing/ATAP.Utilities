using System;
using Microsoft.Extensions.DependencyInjection;

using ATAP.Utilities.Configuration.Secrets.Shims;

namespace ATAP.Utilities.Configuration.Secrets;

/// <summary>
/// DI registration helpers for the IConfigurationSecrets chain.
/// </summary>
[Obsolete("Use ATAP.Utilities.Secrets namespace instead. This type will be removed in a future release.")]
public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registers the complete IConfigurationSecrets chain backed by the specified shim.
    /// </summary>
    /// <typeparam name="TShim">
    /// The <see cref="IConfigurationSecretsShim"/> implementation to use as the
    /// secrets back-end (e.g. <c>BitwardenSecretsShim</c>).
    /// </typeparam>
    public static IServiceCollection AddConfigurationSecrets<TShim>(
        this IServiceCollection services)
        where TShim : class, IConfigurationSecretsShim
    {
        services.AddSingleton<IConfigurationSecretsShim, TShim>();
        services.AddSingleton<IConfigurationSecrets, ConfigurationSecretsShims>();
        return services;
    }

    /// <summary>
    /// Registers the complete IConfigurationSecrets chain backed by an
    /// <see cref="ATAP.Utilities.Secrets.ISecretsAbstract"/> provider — typically
    /// one loaded via the ATAP.Utilities.Secrets plugin architecture.
    /// The provider is wrapped in a <see cref="SecretsAbstractShimAdapter"/> to
    /// bridge it into the Configuration.Secrets type system.
    /// </summary>
    /// <param name="services">The DI service collection.</param>
    /// <param name="secretsProvider">
    /// An <see cref="ATAP.Utilities.Secrets.ISecretsAbstract"/> instance, e.g. a
    /// <c>BitwardenSecretsShim</c> discovered at runtime by <c>SecretsPluginShim</c>.
    /// </param>
    public static IServiceCollection AddConfigurationSecretsFromProvider(
        this IServiceCollection services,
        ATAP.Utilities.Secrets.ISecretsAbstract secretsProvider)
    {
        services.AddSingleton<IConfigurationSecretsShim>(
            new SecretsAbstractShimAdapter(secretsProvider));
        services.AddSingleton<IConfigurationSecrets, ConfigurationSecretsShims>();
        return services;
    }
}
