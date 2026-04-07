using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

using ATAP.Utilities.Configuration.Secrets;
using ATAP.Utilities.Configuration.Secrets.Shims;
using ATAP.Utilities.FileIO;
using ATAP.Utilities.Loader;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace ATAP.Console.PluginDemo;

public sealed class PluginDemoBackgroundService : BackgroundService
{
  private readonly IConfigurationSecrets _staticSecrets;
  private readonly IAssemblyLoader _assemblyLoader;
  private readonly IConfiguration _configuration;
  private readonly IHostApplicationLifetime _lifetime;
  private readonly ILogger<PluginDemoBackgroundService> _logger;

  public PluginDemoBackgroundService(
    IConfigurationSecrets staticSecrets,
    IAssemblyLoader assemblyLoader,
    IConfiguration configuration,
    IHostApplicationLifetime lifetime,
    ILogger<PluginDemoBackgroundService> logger)
  {
    _staticSecrets = staticSecrets;
    _assemblyLoader = assemblyLoader;
    _configuration = configuration;
    _lifetime = lifetime;
    _logger = logger;
  }

  protected override async Task ExecuteAsync(CancellationToken stoppingToken)
  {
    System.Console.WriteLine(StringConstants.WelcomeMessage);

    while (!stoppingToken.IsCancellationRequested)
    {
      System.Console.WriteLine();
      System.Console.WriteLine(StringConstants.ModeSelectionPrompt);
      var key = System.Console.ReadKey(intercept: true);

      switch (char.ToUpperInvariant(key.KeyChar))
      {
        case '1':
          await DemoStaticReferenceAsync(stoppingToken).ConfigureAwait(false);
          break;
        case '2':
          await DemoDynamicPluginAsync(stoppingToken).ConfigureAwait(false);
          break;
        case 'Q':
          _lifetime.StopApplication();
          return;
        default:
          System.Console.WriteLine("Unknown selection.");
          break;
      }
    }
  }

  private async Task DemoStaticReferenceAsync(CancellationToken cancellationToken)
  {
    System.Console.WriteLine();
    System.Console.WriteLine("--- Mode 1: Static Project Reference ---");

    var secret = await _staticSecrets.GetSecretAsync(
      StringConstants.TestSecretName,
      StringConstants.TestSecretFieldName,
      cancellationToken).ConfigureAwait(false);

    WriteSecretResult(secret);
  }

  private async Task DemoDynamicPluginAsync(CancellationToken cancellationToken)
  {
    System.Console.WriteLine();
    System.Console.WriteLine("--- Mode 2: Dynamic Plugin Loading ---");

    var pluginDirectory = _configuration.GetValue(
      StringConstants.PluginDirectoryConfigRootKey,
      StringConstants.PluginDirectoryDefault) ?? StringConstants.PluginDirectoryDefault;

    var pattern = Path.Combine(AppContext.BaseDirectory, pluginDirectory, StringConstants.SecretsPluginGlobPattern);
    var glob = new DynamicGlobAndPredicate
    {
      Glob = new Glob { Pattern = pattern },
      Predicate = type => typeof(IConfigurationSecretsShim).IsAssignableFrom(type)
        && !type.IsAbstract
        && !type.IsInterface,
    };

    System.Console.WriteLine($"Searching: {pattern}");

    Loader<IConfigurationSecretsShim>? loader = null;
    IConfigurationSecretsShim? dynamicSecrets = null;

    try
    {
      loader = new Loader<IConfigurationSecretsShim>(_assemblyLoader);
      dynamicSecrets = loader.LoadExactlyOneInstanceOfITypeFromAssemblyGlob(glob);
      System.Console.WriteLine($"Loaded provider: {dynamicSecrets.ProviderName}");

      var secret = await dynamicSecrets.GetSecretAsync(
        StringConstants.TestSecretName,
        StringConstants.TestSecretFieldName,
        cancellationToken).ConfigureAwait(false);

      WriteSecretResult(secret);

      System.Console.WriteLine();
      System.Console.WriteLine("Unloading plugin...");
      var weakRef = loader.GetLastLoadedContextWeakReference();
      dynamicSecrets = null;
      loader = null;

      GC.Collect();
      GC.WaitForPendingFinalizers();
      GC.Collect();

      var collected = weakRef != null && !weakRef.IsAlive;
      System.Console.WriteLine(string.Format(StringConstants.UnloadVerificationMessage, collected));
    }
    catch (Exception ex)
    {
      _logger.LogError(ex, "Dynamic plugin loading failed");
      System.Console.WriteLine($"Failed to load plugin: {ex.Message}");
      System.Console.WriteLine("Ensure the Bitwarden shim DLL is in the Plugins directory.");
    }
  }

  private static void WriteSecretResult(string? secret)
  {
    if (string.IsNullOrEmpty(secret))
    {
      System.Console.WriteLine(StringConstants.SecretNotFoundMessage);
      return;
    }

    var prefixLength = Math.Min(secret.Length, 4);
    System.Console.WriteLine(string.Format(StringConstants.SecretRetrievedMessage, secret[..prefixLength]));
  }
}
