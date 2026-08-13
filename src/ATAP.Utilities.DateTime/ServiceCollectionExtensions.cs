using System;
using ATAP.Utilities.DateTime.Interfaces;
using ATAP.Utilities.DateTime.Model;
using Microsoft.Extensions.DependencyInjection;

namespace ATAP.Utilities.DateTime;

/// <summary>
/// Provides dependency-injection registration for ATAP temporal services.
/// </summary>
public static class ServiceCollectionExtensions
{
  /// <summary>
  /// Registers ATAP temporal calculation services.
  /// </summary>
  /// <param name="services">The service collection to update.</param>
  /// <returns>The same service collection.</returns>
  /// <exception cref="ArgumentNullException">Thrown when <paramref name="services"/> is null.</exception>
  public static IServiceCollection AddATAPUtilitiesDateTime(this IServiceCollection services)
  {
    ArgumentNullException.ThrowIfNull(services);
    services.AddSingleton<ITemporalPeriodCalculator, ItensoTemporalPeriodCalculator>();
    return services;
  }
}
