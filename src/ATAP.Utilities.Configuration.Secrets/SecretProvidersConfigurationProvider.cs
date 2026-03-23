using Microsoft.Extensions.Configuration;

namespace ATAP.Utilities.Configuration.Secrets;

/// <summary>
/// Populates IConfiguration values by querying all registered <see cref="ISecretProvider"/> instances.
/// Providers that report <see cref="ISecretProvider.IsAvailable"/> == false are silently skipped.
/// Individual secret fetch failures are logged to <see cref="System.Diagnostics.Debug"/> and skipped
/// so that missing secrets surface as validation errors (via ValidateOnStart) rather than crashing
/// during configuration loading.
/// </summary>
public sealed class SecretProvidersConfigurationProvider : ConfigurationProvider
{
  private readonly SecretProvidersConfigurationSource _source;

  /// <summary>Initializes a new instance of <see cref="SecretProvidersConfigurationProvider"/>.</summary>
  public SecretProvidersConfigurationProvider(SecretProvidersConfigurationSource source) =>
    _source = source;

  /// <inheritdoc />
  public override void Load() => LoadAsync(CancellationToken.None).GetAwaiter().GetResult();

  private async Task LoadAsync(CancellationToken cancellationToken)
  {
    var data = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);

    foreach (var (provider, mappings) in _source.Registrations)
    {
      if (!provider.IsAvailable())
      {
        System.Diagnostics.Debug.WriteLine(
          $"[SecretProviders] {provider.ProviderName} is not available — skipping.");
        continue;
      }

      foreach (var mapping in mappings)
      {
        try
        {
          var value = await provider.GetSecretAsync(
            mapping.SecretName, mapping.FieldName, cancellationToken);

          if (value is not null)
            data[mapping.ConfigurationKey] = value;
        }
        catch (Exception ex)
        {
          // Don't fail startup. Missing secrets surface via Options ValidateOnStart.
          // Use Debug.WriteLine because ILogger is not yet available during config loading.
          System.Diagnostics.Debug.WriteLine(
            $"[SecretProviders] {provider.ProviderName} failed to load " +
            $"'{mapping.SecretName}': {ex.Message}");
        }
      }
    }

    Data = data;
  }
}
